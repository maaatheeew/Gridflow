import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @FocusState private var isTitleFieldFocused: Bool

    let task: TaskItem?
    let initialQuadrant: TaskQuadrant
    let presetProjectID: UUID?
    let onSave: (TaskItem) throws -> Void

    @State private var title = ""
    @State private var selectedQuadrant: TaskQuadrant = .importantNotUrgent
    @State private var selectedProjectID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(l(task == nil ? "task.editor.new" : "task.editor.edit"))
                    .font(AppFont.hero)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Button(l("common.cancel"), role: .cancel) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .keyboardShortcut(.cancelAction)

                Button(l("common.save")) {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            VStack(alignment: .leading, spacing: 18) {
                titleFieldCard

                editorSection {
                    editorPickerRow(title: l("task.quadrant"), selection: $selectedQuadrant) {
                        ForEach(TaskQuadrant.allCases) { quadrant in
                            Text(l(quadrant.titleKey)).tag(quadrant)
                        }
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(AppFont.footnote)
                    .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .frame(width: 620, alignment: .topLeading)
        .onAppear(perform: loadState)
    }

    private func loadState() {
        guard let task else {
            selectedQuadrant = initialQuadrant
            selectedProjectID = presetProjectID
            DispatchQueue.main.async {
                isTitleFieldFocused = true
            }
            return
        }

        title = task.title
        selectedQuadrant = task.quadrant
        selectedProjectID = task.projectID

        DispatchQueue.main.async {
            isTitleFieldFocused = true
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        var target = task ?? TaskItem(
            title: trimmedTitle,
            quadrant: selectedQuadrant,
            order: Date().timeIntervalSince1970,
            projectID: nil
        )

        target.title = trimmedTitle
        target.dueDate = nil
        target.quadrant = selectedQuadrant
        target.projectID = selectedProjectID
        target.status = .active
        target.completedAt = nil
        target.completedFromQuadrant = nil
        target.completedFromProjectID = nil
        target.completedFromProjectName = nil

        do {
            try onSave(target)
            dismiss()
        } catch {
            errorMessage = l("task.editor.save_error")
        }
    }

    private func l(_ key: String) -> String {
        AppLocalizer.string(key, locale: locale)
    }

    private var titleFieldCard: some View {
        editorSection {
            TextField(
                "",
                text: $title,
                prompt: Text(l("task.title"))
                    .foregroundStyle(AppTheme.secondaryText)
            )
            .textFieldStyle(.plain)
            .font(AppFont.body)
            .focused($isTitleFieldFocused)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    private func editorSection<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func editorPickerRow<SelectionValue: Hashable, Content: View>(
        title: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(AppFont.bodySemibold)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Picker("", selection: selection) {
                content()
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.large)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}
