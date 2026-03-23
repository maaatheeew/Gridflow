import SwiftUI

enum SidebarSelection: Hashable {
    case project(UUID)
}

struct SidebarView: View {
    @Environment(\.locale) private var locale

    @Binding var selection: SidebarSelection?
    @FocusState private var focusedProjectID: UUID?
    @State private var editingProjectID: UUID?
    @State private var draftProjectName = ""

    let tasks: [TaskItem]
    let projects: [Project]
    let onCreateProject: () -> Project?
    let onOpenLog: () -> Void
    let onOpenSettings: () -> Void
    let onRenameProject: (Project, String) -> Void
    let onDeleteProject: (Project) -> Void

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(projects, id: \.id) { project in
                    let isSelected = selection == .project(project.id)

                    HStack {
                        projectNameView(for: project)

                        Text("\(count(for: project))")
                            .foregroundStyle(isSelected ? AppTheme.selectedText : AppTheme.secondaryText)
                    }
                    .padding(.vertical, 3)
                    .tag(SidebarSelection.project(project.id))
                    .listRowInsets(projectRowInsets)
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded {
                            beginRenaming(project)
                        }
                    )
                    .contextMenu {
                        Button {
                            beginRenaming(project)
                        } label: {
                            Label(l("project.rename"), systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDeleteProject(project)
                        } label: {
                            Label(l("project.delete"), systemImage: "trash")
                        }
                    }
                }

                Button {
                    if let project = onCreateProject() {
                        beginRenaming(project, startEmpty: true)
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.primaryAccent)

                        Text(l("project.create_action"))
                            .foregroundStyle(AppTheme.primaryAccent)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
                .listRowInsets(projectRowInsets)
            } header: {
                Text(l("sidebar.projects"))
                    .padding(.bottom, 6)
            }
        }
        .listStyle(.sidebar)
        .environment(\.controlActiveState, .key)
        .background(
            ScrollViewChromeReader { scrollView in
                AppScrollViewChrome.applyThinStyle(to: scrollView)
            }
        )
        .onChange(of: focusedProjectID) {
            guard let editingProjectID, focusedProjectID != editingProjectID else { return }
            commitProjectRename()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                SidebarFooterButton(
                    title: l("sidebar.log"),
                    systemImage: "clock",
                    action: onOpenLog
                )

                SidebarFooterButton(
                    title: l("settings.title"),
                    systemImage: "gearshape",
                    action: onOpenSettings
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
    }

    private func count(for project: Project) -> Int {
        tasks.filter { $0.projectID == project.id && $0.status == .active }.count
    }

    @ViewBuilder
    private func projectNameView(for project: Project) -> some View {
        if editingProjectID == project.id {
            TextField("", text: $draftProjectName)
                .textFieldStyle(.plain)
                .font(AppFont.bodySemibold)
                .foregroundStyle(.primary)
                .focused($focusedProjectID, equals: project.id)
                .onSubmit {
                    commitProjectRename()
                }
                .onExitCommand {
                    cancelProjectRename()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(project.name)
                .font(AppFont.bodySemibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func beginRenaming(_ project: Project, startEmpty: Bool = false) {
        selection = .project(project.id)
        editingProjectID = project.id
        draftProjectName = startEmpty ? "" : project.name

        DispatchQueue.main.async {
            focusedProjectID = project.id
        }
    }

    private func commitProjectRename() {
        guard let editingProjectID,
              let project = projects.first(where: { $0.id == editingProjectID }) else {
            cancelProjectRename()
            return
        }

        let trimmedName = draftProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedName == project.name {
            cancelProjectRename()
            return
        }

        onRenameProject(project, trimmedName)
        clearProjectRenameState()
    }

    private func cancelProjectRename() {
        clearProjectRenameState()
    }

    private func clearProjectRenameState() {
        focusedProjectID = nil
        editingProjectID = nil
        draftProjectName = ""
    }

    private var projectRowInsets: EdgeInsets {
        EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)
    }

    private func l(_ key: String) -> String {
        AppLocalizer.string(key, locale: locale)
    }
}

private struct SidebarFooterButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(AppTheme.secondaryText)

                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
