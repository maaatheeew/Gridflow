import Foundation

struct Project: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = .now
}

struct SubtaskItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var createdAt: Date = .now
}

struct TaskItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    var createdAt: Date = .now
    var dueDate: Date?
    var completedAt: Date?
    var statusRaw: String = TaskStatus.active.rawValue
    var quadrantRaw: Int
    var priorityRaw: Int
    var tagsRaw: String = ""
    var order: Double = 0
    var projectID: UUID?
    var subtasks: [SubtaskItem] = []
    var completedFromQuadrantRaw: Int?
    var completedFromProjectID: UUID?
    var completedFromProjectName: String?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        createdAt: Date = .now,
        dueDate: Date? = nil,
        completedAt: Date? = nil,
        status: TaskStatus = .active,
        quadrant: TaskQuadrant,
        priority: TaskPriority = .medium,
        tagsRaw: String = "",
        order: Double = 0,
        projectID: UUID? = nil,
        subtasks: [SubtaskItem] = [],
        completedFromQuadrant: TaskQuadrant? = nil,
        completedFromProjectID: UUID? = nil,
        completedFromProjectName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.statusRaw = status.rawValue
        self.quadrantRaw = quadrant.rawValue
        self.priorityRaw = priority.rawValue
        self.tagsRaw = tagsRaw
        self.order = order
        self.projectID = projectID
        self.subtasks = subtasks
        self.completedFromQuadrantRaw = completedFromQuadrant?.rawValue
        self.completedFromProjectID = completedFromProjectID
        self.completedFromProjectName = completedFromProjectName
    }
}

extension TaskItem {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case createdAt
        case dueDate
        case completedAt
        case isCompleted
        case statusRaw
        case quadrantRaw
        case priorityRaw
        case tagsRaw
        case order
        case projectID
        case subtasks
        case completedFromQuadrantRaw
        case completedFromProjectID
        case completedFromProjectName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        quadrantRaw = try container.decodeIfPresent(Int.self, forKey: .quadrantRaw) ?? TaskQuadrant.importantNotUrgent.rawValue
        priorityRaw = try container.decodeIfPresent(Int.self, forKey: .priorityRaw) ?? TaskPriority.medium.rawValue
        tagsRaw = try container.decodeIfPresent(String.self, forKey: .tagsRaw) ?? ""
        order = try container.decodeIfPresent(Double.self, forKey: .order) ?? 0
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        subtasks = try container.decodeIfPresent([SubtaskItem].self, forKey: .subtasks) ?? []
        completedFromQuadrantRaw = try container.decodeIfPresent(Int.self, forKey: .completedFromQuadrantRaw)
        completedFromProjectID = try container.decodeIfPresent(UUID.self, forKey: .completedFromProjectID)
        completedFromProjectName = try container.decodeIfPresent(String.self, forKey: .completedFromProjectName)

        let legacyCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        let decodedStatus = try container.decodeIfPresent(String.self, forKey: .statusRaw)
            .flatMap(TaskStatus.init(rawValue:))
            ?? (legacyCompleted ? .completed : .active)
        statusRaw = decodedStatus.rawValue

        if status == .completed {
            if completedAt == nil {
                completedAt = createdAt
            }
            if completedFromQuadrantRaw == nil {
                completedFromQuadrantRaw = quadrantRaw
            }
            if completedFromProjectID == nil {
                completedFromProjectID = projectID
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(statusRaw, forKey: .statusRaw)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(quadrantRaw, forKey: .quadrantRaw)
        try container.encode(priorityRaw, forKey: .priorityRaw)
        try container.encode(tagsRaw, forKey: .tagsRaw)
        try container.encode(order, forKey: .order)
        try container.encodeIfPresent(projectID, forKey: .projectID)
        try container.encode(subtasks, forKey: .subtasks)
        try container.encodeIfPresent(completedFromQuadrantRaw, forKey: .completedFromQuadrantRaw)
        try container.encodeIfPresent(completedFromProjectID, forKey: .completedFromProjectID)
        try container.encodeIfPresent(completedFromProjectName, forKey: .completedFromProjectName)
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var isCompleted: Bool {
        get { status == .completed }
        set { status = newValue ? .completed : .active }
    }

    var quadrant: TaskQuadrant {
        get { TaskQuadrant(rawValue: quadrantRaw) ?? .importantNotUrgent }
        set { quadrantRaw = newValue.rawValue }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var tags: [String] {
        get {
            tagsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            tagsRaw = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
    }

    var isDueToday: Bool {
        guard let dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isOverdue: Bool {
        guard let dueDate else { return false }
        return !isCompleted && dueDate < Date()
    }

    var isPlanned: Bool {
        dueDate != nil
    }

    var completedFromQuadrant: TaskQuadrant? {
        get {
            guard let completedFromQuadrantRaw else { return nil }
            return TaskQuadrant(rawValue: completedFromQuadrantRaw)
        }
        set {
            completedFromQuadrantRaw = newValue?.rawValue
        }
    }
}
