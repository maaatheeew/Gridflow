import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(\.locale) private var locale
    @EnvironmentObject private var store: AppStore

    @State private var selection: SidebarSelection?
    @State private var editorContext: TaskEditorContext?
    @State private var isShowingLog = false
    @State private var isShowingSettings = false
    @State private var alertInfo: AlertInfo?

    private var tasks: [TaskItem] { store.tasks }
    private var activeTasks: [TaskItem] { store.activeTasks }
    private var completedTasks: [TaskItem] { store.completedTasks }
    private var projects: [Project] { store.projects }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $selection,
                tasks: tasks,
                projects: projects,
                onCreateProject: createProject,
                onOpenLog: {
                    isShowingLog = true
                },
                onOpenSettings: {
                    isShowingSettings = true
                },
                onRenameProject: renameProject,
                onDeleteProject: deleteProject
            )
            .navigationSplitViewColumnWidth(min: 210, ideal: 245, max: 280)
        } detail: {
            ZStack {
                appBackgroundColor.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    if let selectedProject {
                        Text(selectedProject.name)
                            .font(AppFont.quadrantTitle)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("")
                            .font(AppFont.quadrantTitle)
                    }

                    MatrixBoardView(
                        tasks: filteredTasks,
                        showsAuxiliaryControls: true,
                        onCompleteTask: completeTask,
                        onOpenTask: editTask,
                        onDeleteTask: deleteTask,
                        onMoveTask: moveTask,
                        onQuickAdd: presentNewTask
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
        }
        .sheet(item: $editorContext) { context in
            TaskEditorView(
                task: context.task,
                initialQuadrant: context.initialQuadrant,
                presetProjectID: context.presetProjectID,
                onSave: { task in
                    try store.upsertTask(task)
                }
            )
            .environment(\.locale, locale)
            .appWindowChrome()
        }
        .sheet(isPresented: $isShowingLog) {
            CompletedLogView(
                tasks: completedTasks,
                projects: projects,
                onRestoreTask: restoreTaskFromLog,
                onDeleteTask: deleteTask,
                onClearCompletedTasks: clearCompletedTasks
            )
            .environment(\.locale, locale)
            .frame(width: 700, height: 540)
            .appWindowChrome()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                onImportJSON: importJSON,
                onExportJSON: exportJSON
            )
            .environment(\.locale, locale)
            .appWindowChrome()
        }
        .alert(
            alertInfo?.title ?? "",
            isPresented: Binding(
                get: { alertInfo != nil },
                set: { value in
                    if !value {
                        alertInfo = nil
                    }
                }
            )
        ) {
            Button(l("common.ok"), role: .cancel) { }
        } message: {
            Text(alertInfo?.message ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTaskCommand)) { _ in
            presentNewTask(quadrant: .importantNotUrgent)
        }
        .onReceive(NotificationCenter.default.publisher(for: .undoCommand)) { _ in
            performUndo()
        }
        .onAppear(perform: ensureValidSelection)
        .onChange(of: projects) {
            ensureValidSelection()
        }
        .appWindowChrome()
    }

    private var filteredTasks: [TaskItem] {
        var result = activeTasks

        if let selectedProjectID {
            result = result.filter { $0.projectID == selectedProjectID }
        } else {
            result = []
        }

        result.sort { lhs, rhs in
            if lhs.order == rhs.order {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.order > rhs.order
        }

        return result
    }

    private var appBackgroundColor: Color {
        AppTheme.windowBackground
    }

    @discardableResult
    private func createProject() -> Project? {
        do {
            let project = try store.createProject(name: l("project.new"))
            selection = .project(project.id)
            return project
        } catch {
            alertInfo = AlertInfo(
                title: l("common.error"),
                message: l("project.save_error")
            )
            return nil
        }
    }

    private func deleteProject(_ project: Project) {
        do {
            try store.deleteProject(project)
            ensureValidSelection()
        } catch {
            alertInfo = AlertInfo(
                title: l("common.error"),
                message: l("project.delete_error")
            )
        }
    }

    private func renameProject(_ project: Project, to name: String) {
        do {
            try store.renameProject(id: project.id, to: name)
        } catch {
            alertInfo = AlertInfo(
                title: l("common.error"),
                message: l("project.rename_error")
            )
        }
    }

    private func presentNewTask(quadrant: TaskQuadrant) {
        let presetProjectID: UUID?
        if case .project(let projectID) = selection {
            presetProjectID = projectID
        } else {
            presetProjectID = nil
        }

        editorContext = TaskEditorContext(
            task: nil,
            initialQuadrant: quadrant,
            presetProjectID: presetProjectID
        )
    }

    private func editTask(_ task: TaskItem) {
        editorContext = TaskEditorContext(
            task: task,
            initialQuadrant: task.quadrant,
            presetProjectID: nil
        )
    }

    private func completeTask(_ task: TaskItem) {
        do {
            try store.completeTask(id: task.id)
        } catch {
            alertInfo = AlertInfo(
                title: l("common.error"),
                message: l("task.toggle_error")
            )
        }
    }

    private func moveTask(_ taskID: UUID, to quadrant: TaskQuadrant, before beforeTaskID: UUID?) {
        do {
            try withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                try store.moveTask(id: taskID, to: quadrant, before: beforeTaskID)
            }
        } catch {
            alertInfo = AlertInfo(
                title: l("common.error"),
                message: l("task.move_error")
            )
        }
    }

    private func deleteTask(_ task: TaskItem) {
        do {
            try store.deleteTask(id: task.id)
        } catch {
            alertInfo = AlertInfo(
                title: l("common.error"),
                message: l("task.delete_error")
            )
        }
    }

    private func clearCompletedTasks() {
        do {
            try store.clearCompletedTasks()
        } catch {
            alertInfo = AlertInfo(
                title: l("common.error"),
                message: l("log.clear_error")
            )
        }
    }

    private func restoreTaskFromLog(_ task: TaskItem) {
        do {
            _ = try store.restoreCompletedTask(id: task.id)
        } catch {
            alertInfo = AlertInfo(
                title: l("common.error"),
                message: l("task.toggle_error")
            )
        }
    }

    private func performUndo() {
        do {
            _ = try store.undoLastChange()
        } catch {
            alertInfo = AlertInfo(
                title: l("common.error"),
                message: l("undo.error")
            )
        }
    }

    private func exportJSON() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "gridflow-export.json"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try ImportExportService.exportJSON(tasks: tasks, projects: projects)
            try data.write(to: url)
            alertInfo = AlertInfo(
                title: l("io.export_done"),
                message: l("io.export_json_done")
            )
        } catch {
            alertInfo = AlertInfo(
                title: l("common.error"),
                message: l("io.export_error")
            )
        }
    }

    private func importJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let imported = try ImportExportService.importJSON(data)
            let result = try store.replaceData(projects: imported.projects, tasks: imported.tasks)
            alertInfo = AlertInfo(
                title: l("io.import_done"),
                message: AppLocalizer.format("io.import_done_message", locale: locale, result.0, result.1)
            )
        } catch {
            alertInfo = AlertInfo(
                title: l("common.error"),
                message: l("io.import_error")
            )
        }
    }

    private func l(_ key: String) -> String {
        AppLocalizer.string(key, locale: locale)
    }

    private var selectedProjectID: UUID? {
        guard case .project(let projectID)? = selection else { return nil }
        return projectID
    }

    private var selectedProject: Project? {
        guard let selectedProjectID else { return nil }
        return projects.first(where: { $0.id == selectedProjectID })
    }

    private func ensureValidSelection() {
        if let selectedProjectID,
           projects.contains(where: { $0.id == selectedProjectID }) {
            return
        }

        if let firstProject = projects.first {
            selection = .project(firstProject.id)
        } else {
            selection = nil
        }
    }
}

private struct TaskEditorContext: Identifiable {
    let id = UUID()
    let task: TaskItem?
    let initialQuadrant: TaskQuadrant
    let presetProjectID: UUID?
}

private struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct FilterBarView: View {
    @Environment(\.locale) private var locale

    @Binding var selectedPriorities: Set<TaskPriority>
    @Binding var selectedQuadrants: Set<TaskQuadrant>
    @Binding var showOnlyOverdue: Bool
    @Binding var includeCompleted: Bool
    @Binding var sortMode: TaskSortMode

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                sortModeControl
                filterMenuControl
                glassToggle(title: l("filter.overdue.short"), isOn: $showOnlyOverdue)
                glassToggle(title: l("filter.include_completed.short"), isOn: $includeCompleted)
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(panelFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(panelBorderColor, lineWidth: 1)
        )
    }

    private var sortModeControl: some View {
        HStack(spacing: 6) {
            ForEach(TaskSortMode.allCases) { mode in
                sortModeChip(mode)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(glassBorderColor, lineWidth: 1)
        )
    }

    private func sortModeChip(_ mode: TaskSortMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                sortMode = mode
            }
        } label: {
            Text(l(mode.titleKey))
                .font(AppFont.subheadline)
                .foregroundStyle(sortMode == mode ? activeChipForeground : .primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(sortMode == mode ? activeChipBackground : inactiveChipBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            sortMode == mode ? activeChipBorder : inactiveChipBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var filterMenuControl: some View {
        Menu {
            Section(l("filter.priority")) {
                ForEach(TaskPriority.allCases) { priority in
                    Button {
                        togglePriority(priority)
                    } label: {
                        Label(
                            l(priority.titleKey),
                            systemImage: selectedPriorities.contains(priority)
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                    }
                }
            }

            Divider()

            Section(l("filter.quadrants")) {
                ForEach(TaskQuadrant.allCases) { quadrant in
                    Button {
                        toggleQuadrant(quadrant)
                    } label: {
                        Label(
                            l(quadrant.titleKey),
                            systemImage: selectedQuadrants.contains(quadrant)
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                    }
                }
            }
        } label: {
            Label(l("filter.menu"), systemImage: "line.3.horizontal.decrease.circle")
                .font(AppFont.subheadline)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(glassBorderColor, lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
    }

    private func glassToggle(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppFont.subheadline)
                .lineLimit(1)

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(glassBorderColor, lineWidth: 1)
            )
    }

    private var activeChipForeground: Color {
        AppTheme.primaryAccent
    }

    private var activeChipBackground: Color {
        AppTheme.primaryAccent.opacity(0.12)
    }

    private var activeChipBorder: Color {
        AppTheme.primaryAccent.opacity(0.28)
    }

    private var inactiveChipBackground: Color {
        AppTheme.subtleFill
    }

    private var inactiveChipBorder: Color {
        AppTheme.mutedBorder
    }

    private var glassBorderColor: Color {
        AppTheme.border
    }

    private var panelFillColor: Color {
        AppTheme.cardFill
    }

    private var panelBorderColor: Color {
        AppTheme.border
    }

    private func togglePriority(_ priority: TaskPriority) {
        if selectedPriorities.contains(priority) {
            if selectedPriorities.count > 1 {
                selectedPriorities.remove(priority)
            }
        } else {
            selectedPriorities.insert(priority)
        }
    }

    private func toggleQuadrant(_ quadrant: TaskQuadrant) {
        if selectedQuadrants.contains(quadrant) {
            if selectedQuadrants.count > 1 {
                selectedQuadrants.remove(quadrant)
            }
        } else {
            selectedQuadrants.insert(quadrant)
        }
    }

    private func l(_ key: String) -> String {
        AppLocalizer.string(key, locale: locale)
    }
}
