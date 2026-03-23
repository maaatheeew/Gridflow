import SwiftUI

struct CompletedLogView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let tasks: [TaskItem]
    let projects: [Project]
    let onRestoreTask: (TaskItem) -> Void
    let onDeleteTask: ((TaskItem) -> Void)?
    let onClearCompletedTasks: () -> Void

    @State private var isShowingClearConfirmation = false

    private let contentInset: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            if groupedTasks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 30) {
                        ForEach(groupedTasks) { section in
                            VStack(alignment: .leading, spacing: 14) {
                                dayHeader(for: section.day)

                                ForEach(section.tasks, id: \.id) { task in
                                    CompletedLogRow(
                                        task: task,
                                        projectName: projectName(for: task),
                                        quadrantTitle: l((task.completedFromQuadrant ?? task.quadrant).titleKey),
                                        quadrantAccent: (task.completedFromQuadrant ?? task.quadrant).accentColor,
                                        timeText: formattedTime(for: task),
                                        contentInset: contentInset,
                                        onRestoreTask: { onRestoreTask(task) },
                                        onDeleteTask: onDeleteTask.map { handler in
                                            { handler(task) }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .background(
                    ScrollViewChromeReader { scrollView in
                        AppScrollViewChrome.applyInsetOverlayStyle(to: scrollView)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 26)
        .alert(
            l("log.clear_confirm_title"),
            isPresented: $isShowingClearConfirmation
        ) {
            Button(l("common.cancel"), role: .cancel) { }
            Button(l("log.clear_confirm_action"), role: .destructive) {
                onClearCompletedTasks()
            }
        } message: {
            Text(l("log.clear_confirm_message"))
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(l("log.title"))
                .font(AppFont.hero)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if !groupedTasks.isEmpty {
                    Button(l("log.clear")) {
                        isShowingClearConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                Button(l("common.done")) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l("log.empty_hint"))
                .font(AppFont.body)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayHeader(for date: Date) -> some View {
        Text(formattedDayHeader(for: date))
            .font(AppFont.section)
            .foregroundStyle(.primary)
            .textCase(nil)
    }

    private var groupedTasks: [CompletionSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: tasks) { task in
            calendar.startOfDay(for: task.completedAt ?? task.createdAt)
        }

        return grouped
            .map { day, items in
                CompletionSection(
                    day: day,
                    tasks: items.sorted { lhs, rhs in
                        let lhsDate = lhs.completedAt ?? lhs.createdAt
                        let rhsDate = rhs.completedAt ?? rhs.createdAt

                        if lhsDate == rhsDate {
                            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                        }

                        return lhsDate < rhsDate
                    }
                )
            }
            .sorted { $0.day > $1.day }
    }

    private func formattedDayHeader(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private func formattedTime(for task: TaskItem) -> String {
        timeFormatter.string(from: task.completedAt ?? task.createdAt)
    }

    private func projectName(for task: TaskItem) -> String? {
        let resolvedProjectID = task.completedFromProjectID ?? task.projectID

        if let resolvedProjectID,
           let project = projects.first(where: { $0.id == resolvedProjectID }) {
            return project.name
        }

        if let fallbackName = task.completedFromProjectName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !fallbackName.isEmpty {
            return fallbackName
        }

        return nil
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter
    }
    private func l(_ key: String) -> String {
        AppLocalizer.string(key, locale: locale)
    }
}

private struct CompletionSection: Identifiable {
    let day: Date
    let tasks: [TaskItem]

    var id: Date { day }
}

private struct CompletedLogRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    let task: TaskItem
    let projectName: String?
    let quadrantTitle: String
    let quadrantAccent: Color
    let timeText: String
    let contentInset: CGFloat
    let onRestoreTask: () -> Void
    let onDeleteTask: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if let projectName {
                    metadataLine(projectName: projectName)
                } else {
                    Text(quadrantTitle)
                        .font(AppFont.captionSemibold)
                        .foregroundStyle(quadrantAccent)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(timeText)
                .font(AppFont.captionSemibold)
                .monospacedDigit()
                .foregroundStyle(AppTheme.secondaryText)
                .frame(minWidth: 58, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, contentInset)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering ? hoverFillColor : rowFillColor)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(action: onRestoreTask) {
                Label(l("log.restore"), systemImage: "arrow.uturn.backward.circle")
            }

            if let onDeleteTask {
                Button(role: .destructive, action: onDeleteTask) {
                    Label(l("log.delete"), systemImage: "trash")
                }
            }
        }
    }

    private var rowFillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.09)
            : Color.black.opacity(0.05)
    }

    private var hoverFillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.09)
    }

    @ViewBuilder
    private func metadataLine(projectName: String) -> some View {
        (
            Text(projectName)
                .foregroundStyle(AppTheme.secondaryText)
            + Text(" • ")
                .foregroundStyle(AppTheme.quaternaryText)
            + Text(quadrantTitle)
                .foregroundStyle(quadrantAccent)
        )
        .font(AppFont.captionSemibold)
        .lineLimit(1)
    }

    private func l(_ key: String) -> String {
        AppLocalizer.string(key, locale: locale)
    }
}
