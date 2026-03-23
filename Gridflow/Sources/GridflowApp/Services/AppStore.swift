import Foundation

struct AppSnapshot: Codable {
    var projects: [Project]
    var tasks: [TaskItem]
}

struct LocalPersistenceService {
    let fileURL: URL

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let folder = appSupport.appendingPathComponent(AppMetadata.storageFolderName, isDirectory: true)
        self.fileURL = folder.appendingPathComponent(AppMetadata.storageFileName)
    }

    func load() throws -> AppSnapshot {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return AppSnapshot(projects: [], tasks: [])
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppSnapshot.self, from: data)
    }

    func save(snapshot: AppSnapshot) throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var tasks: [TaskItem] = []

    private let persistence: LocalPersistenceService
    private var undoHistory: [AppSnapshot] = []
    private let maxUndoDepth: Int = 50

    init(persistence: LocalPersistenceService = LocalPersistenceService()) {
        self.persistence = persistence

        do {
            let snapshot = try persistence.load()
            projects = snapshot.projects
            tasks = snapshot.tasks.sorted(by: Self.orderComparator)
            try ensureDefaultProject()
            normalizeLegacyLocalizedValues()
        } catch {
            projects = [Project(name: AppMetadata.defaultProjectName)]
            tasks = []
            try? persist()
        }
    }

    func project(for id: UUID?) -> Project? {
        guard let id else { return nil }
        return projects.first(where: { $0.id == id })
    }

    var activeTasks: [TaskItem] {
        tasks
            .filter { $0.status == .active }
            .sorted(by: Self.orderComparator)
    }

    var completedTasks: [TaskItem] {
        tasks
            .filter { $0.status == .completed }
            .sorted(by: Self.completionComparator)
    }

    var canUndo: Bool {
        !undoHistory.isEmpty
    }

    @discardableResult
    func createProject(name: String) throws -> Project {
        pushUndoSnapshot()
        let project = Project(name: name)
        projects.append(project)
        try persist()
        return project
    }

    func deleteProject(_ project: Project) throws {
        guard projects.contains(where: { $0.id == project.id }) else { return }
        pushUndoSnapshot()
        projects.removeAll { $0.id == project.id }
        tasks = tasks.map { task in
            var updated = task
            if updated.projectID == project.id, updated.status == .active {
                updated.projectID = nil
            }
            if updated.completedFromProjectID == project.id, updated.completedFromProjectName == nil {
                updated.completedFromProjectName = project.name
            }
            return updated
        }
        try ensureDefaultProject()
        try persist()
    }

    func renameProject(id: UUID, to name: String) throws {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, projects[index].name != trimmedName else { return }

        pushUndoSnapshot()
        projects[index].name = trimmedName
        try persist()
    }

    func upsertTask(_ task: TaskItem) throws {
        pushUndoSnapshot()
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            let previousTask = tasks[index]
            var updatedTask = task
            let didMoveQuadrant = previousTask.status == .active
                && updatedTask.status == .active
                && previousTask.quadrant != updatedTask.quadrant

            if didMoveQuadrant {
                updatedTask.order = nextOrder(in: updatedTask.quadrant)
            }

            tasks[index] = updatedTask

            if didMoveQuadrant {
                normalizeOrder(in: previousTask.quadrant)
            }
        } else {
            var newTask = task
            if newTask.status == .active, newTask.order == 0 {
                newTask.order = nextOrder(in: newTask.quadrant)
            }
            tasks.append(newTask)
        }
        try persist()
    }

    func completeTask(id: UUID) throws {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard tasks[index].status == .active else { return }
        pushUndoSnapshot()

        let quadrant = tasks[index].quadrant
        tasks[index].status = .completed
        tasks[index].completedAt = .now
        tasks[index].completedFromQuadrant = quadrant
        tasks[index].completedFromProjectID = tasks[index].projectID
        tasks[index].completedFromProjectName = project(for: tasks[index].projectID)?.name

        normalizeOrder(in: quadrant)
        try persist()
    }

    @discardableResult
    func restoreCompletedTask(id: UUID) throws -> TaskItem? {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return nil }
        guard tasks[index].status == .completed else { return nil }

        pushUndoSnapshot()

        var restoredTask = tasks[index]
        let restoredQuadrant = restoredTask.completedFromQuadrant ?? restoredTask.quadrant
        let restoredProjectID = try ensureProjectExistsForRestore(
            preferredID: restoredTask.completedFromProjectID,
            fallbackName: restoredTask.completedFromProjectName
        )

        restoredTask.status = .active
        restoredTask.completedAt = nil
        restoredTask.quadrant = restoredQuadrant
        restoredTask.projectID = restoredProjectID
        restoredTask.order = nextOrder(in: restoredQuadrant)
        restoredTask.completedFromQuadrant = nil
        restoredTask.completedFromProjectID = nil
        restoredTask.completedFromProjectName = nil

        tasks[index] = restoredTask
        try persist()

        return restoredTask
    }

    func deleteTask(id: UUID) throws {
        guard tasks.contains(where: { $0.id == id }) else { return }
        pushUndoSnapshot()
        tasks.removeAll { $0.id == id }
        try persist()
    }

    func clearCompletedTasks() throws {
        guard tasks.contains(where: { $0.status == .completed }) else { return }
        pushUndoSnapshot()
        tasks.removeAll { $0.status == .completed }
        try persist()
    }

    func moveTask(id: UUID, to quadrant: TaskQuadrant, before beforeTaskID: UUID? = nil) throws {
        guard let movingIndex = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard tasks[movingIndex].status == .active else { return }

        let sourceQuadrant = tasks[movingIndex].quadrant
        let currentTargetIDs = tasks
            .filter { $0.status == .active && $0.quadrant == quadrant }
            .sorted(by: Self.orderComparator)
            .map(\.id)

        var reorderedTargetIDs = currentTargetIDs.filter { $0 != id }
        let insertionIndex: Int
        if let beforeTaskID, let index = reorderedTargetIDs.firstIndex(of: beforeTaskID) {
            insertionIndex = index
        } else {
            insertionIndex = reorderedTargetIDs.count
        }
        reorderedTargetIDs.insert(id, at: insertionIndex)

        if sourceQuadrant == quadrant && currentTargetIDs == reorderedTargetIDs {
            return
        }

        pushUndoSnapshot()
        applyOrder(for: reorderedTargetIDs, in: quadrant)

        if sourceQuadrant != quadrant {
            normalizeOrder(in: sourceQuadrant)
        }

        try persist()
    }

    func task(for id: UUID) -> TaskItem? {
        tasks.first(where: { $0.id == id })
    }

    func replaceData(projects incomingProjects: [Project], tasks incomingTasks: [TaskItem]) throws -> (Int, Int) {
        pushUndoSnapshot()
        var projectMap = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })

        var projectUpserts = 0
        for project in incomingProjects {
            if projectMap[project.id] == nil {
                projectUpserts += 1
            }
            projectMap[project.id] = project
        }

        projects = Array(projectMap.values).sorted { $0.createdAt < $1.createdAt }

        var taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })

        var taskUpserts = 0
        for task in incomingTasks {
            if taskMap[task.id] == nil {
                taskUpserts += 1
            }
            taskMap[task.id] = task
        }

        tasks = Array(taskMap.values).sorted(by: Self.orderComparator)

        try ensureDefaultProject()
        try persist()

        return (projectUpserts, taskUpserts)
    }

    @discardableResult
    func undoLastChange() throws -> Bool {
        guard let previous = undoHistory.popLast() else { return false }
        projects = previous.projects
        tasks = previous.tasks
        try ensureDefaultProject()
        try persist()
        return true
    }

    private func ensureDefaultProject() throws {
        guard projects.isEmpty else { return }
        projects = [Project(name: AppMetadata.defaultProjectName)]
        try persist()
    }

    private func normalizeLegacyLocalizedValues() {
        let localizedDefault = AppMetadata.defaultProjectName
        var changed = false

        for index in projects.indices where projects[index].name == "project.main" {
            projects[index].name = localizedDefault
            changed = true
        }

        if changed {
            try? persist()
        }
    }

    private func persist() throws {
        try persistence.save(snapshot: AppSnapshot(projects: projects, tasks: tasks))
    }

    private func pushUndoSnapshot() {
        undoHistory.append(AppSnapshot(projects: projects, tasks: tasks))
        if undoHistory.count > maxUndoDepth {
            undoHistory.removeFirst(undoHistory.count - maxUndoDepth)
        }
    }

    private static func orderComparator(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.order == rhs.order {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.order > rhs.order
    }

    private static func completionComparator(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        let lhsDate = lhs.completedAt ?? lhs.createdAt
        let rhsDate = rhs.completedAt ?? rhs.createdAt

        if lhsDate == rhsDate {
            return lhs.createdAt > rhs.createdAt
        }

        return lhsDate > rhsDate
    }

    private func normalizeOrder(in quadrant: TaskQuadrant) {
        let orderedIDs = tasks
            .filter { $0.status == .active && $0.quadrant == quadrant }
            .sorted(by: Self.orderComparator)
            .map(\.id)
        applyOrder(for: orderedIDs, in: quadrant)
    }

    private func applyOrder(for orderedIDs: [UUID], in quadrant: TaskQuadrant) {
        let maxOrder = Double(orderedIDs.count)
        for (index, id) in orderedIDs.enumerated() {
            guard let taskIndex = tasks.firstIndex(where: { $0.id == id }) else { continue }
            tasks[taskIndex].quadrant = quadrant
            tasks[taskIndex].order = maxOrder - Double(index)
        }
    }

    private func nextOrder(in quadrant: TaskQuadrant) -> Double {
        let currentMax = tasks
            .filter { $0.status == .active && $0.quadrant == quadrant }
            .map(\.order)
            .max() ?? 0
        return currentMax + 1
    }

    private func ensureProjectExistsForRestore(
        preferredID: UUID?,
        fallbackName: String?
    ) throws -> UUID? {
        guard let preferredID else { return nil }

        if projects.contains(where: { $0.id == preferredID }) {
            return preferredID
        }

        let name = fallbackName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? AppMetadata.defaultProjectName

        projects.append(Project(id: preferredID, name: name))
        projects.sort { $0.createdAt < $1.createdAt }
        return preferredID
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
