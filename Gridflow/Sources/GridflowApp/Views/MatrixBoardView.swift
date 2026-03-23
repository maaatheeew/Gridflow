import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MatrixBoardView: View {
    let tasks: [TaskItem]
    let showsAuxiliaryControls: Bool
    let onCompleteTask: (TaskItem) -> Void
    let onOpenTask: (TaskItem) -> Void
    let onDeleteTask: (TaskItem) -> Void
    let onMoveTask: (UUID, TaskQuadrant, UUID?) -> Void
    let onQuickAdd: (TaskQuadrant) -> Void

    @StateObject private var dragState = MatrixBoardDragState()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                quadrantCell(.importantNotUrgent)
                Divider().overlay(separatorColor)
                quadrantCell(.importantUrgent)
            }
            Divider().overlay(separatorColor)
            HStack(spacing: 0) {
                quadrantCell(.notImportantNotUrgent)
                Divider().overlay(separatorColor)
                quadrantCell(.notImportantUrgent)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(backgroundColor)
        )
    }

    @ViewBuilder
    private func quadrantCell(_ quadrant: TaskQuadrant) -> some View {
        QuadrantCellView(
            quadrant: quadrant,
            tasks: tasksForQuadrant(quadrant),
            dragState: dragState,
            showsAuxiliaryControls: showsAuxiliaryControls,
            onCompleteTask: onCompleteTask,
            onOpenTask: onOpenTask,
            onDeleteTask: onDeleteTask,
            onDropTask: { taskID, beforeTaskID in onMoveTask(taskID, quadrant, beforeTaskID) },
            onQuickAdd: { onQuickAdd(quadrant) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tasksForQuadrant(_ quadrant: TaskQuadrant) -> [TaskItem] {
        tasks.filter { $0.quadrant == quadrant }
    }

    private var separatorColor: Color {
        AppTheme.mutedBorder
    }

    private var borderColor: Color {
        AppTheme.border
    }

    private var backgroundColor: Color {
        AppTheme.cardFill
    }
}

private struct QuadrantCellView: View {
    @Environment(\.locale) private var locale

    let quadrant: TaskQuadrant
    let tasks: [TaskItem]
    @ObservedObject var dragState: MatrixBoardDragState
    let showsAuxiliaryControls: Bool
    let onCompleteTask: (TaskItem) -> Void
    let onOpenTask: (TaskItem) -> Void
    let onDeleteTask: (TaskItem) -> Void
    let onDropTask: (UUID, UUID?) -> Void
    let onQuickAdd: () -> Void

    @State private var taskFrames: [UUID: CGRect] = [:]
    @State private var contentFrame: CGRect = .zero

    private let rowSpacing: CGFloat = 9
    private let placeholderHeight: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(l(quadrant.titleKey))
                        .font(AppFont.header)
                        .foregroundStyle(quadrant.accentColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(l(quadrant.subtitleKey))
                        .font(AppFont.body)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                if showsAuxiliaryControls {
                    QuickAddButton(
                        accent: quadrant.accentColor,
                        action: onQuickAdd
                    )
                    .help(l("task.quick_add"))
                }
            }

            contentArea
        }
        .padding(20)
        .coordinateSpace(name: dropCoordinateSpaceID)
        .background(quadrantDropBackground)
        .overlay(alignment: .topLeading) {
            placeholderOverlay
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: dragState.dropTarget)
        .onPreferenceChange(MatrixTaskFramePreferenceKey.self) { frames in
            taskFrames = frames
        }
        .onPreferenceChange(MatrixContentFramePreferenceKey.self) { frame in
            if !frame.equalTo(.zero) {
                contentFrame = frame
            }
        }
        .onDrop(
            of: [UTType.text],
            delegate: MatrixTaskDropDelegate(
                quadrant: quadrant,
                dragState: dragState,
                rowFrames: taskFrames,
                contentFrame: contentFrame,
                onPerformDrop: onDropTask
            )
        )
    }

    private var contentArea: some View {
        Group {
            if tasks.isEmpty {
                emptyState
            } else {
                scrollableTaskList
            }
        }
        .background(contentFrameReader)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l("matrix.empty"))
                .font(AppFont.footnote)
                .foregroundStyle(AppTheme.secondaryText)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var scrollableTaskList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            taskListContent
        }
        .background(
            ScrollViewChromeReader { resolvedScrollView in
                AppScrollViewChrome.applyPersistentVerticalStyle(to: resolvedScrollView)
            }
        )
    }

    private var taskListContent: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(tasks, id: \.id) { task in
                taskRow(task)
                    .id("\(task.id.uuidString)-\(task.statusRaw)-\(task.completedAt?.timeIntervalSince1970 ?? -1)")
                    .background(taskFrameReader(for: task.id))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func taskRow(_ task: TaskItem) -> some View {
        MatrixTaskRow(
            task: task,
            accent: quadrant.accentColor,
            isBeingDragged: dragState.isDragging(taskID: task.id),
            onCompleteTask: { onCompleteTask(task) },
            onOpenTask: { onOpenTask(task) },
            onDeleteTask: { onDeleteTask(task) }
        )
        .onDrag {
            dragState.beginDragging(taskID: task.id, from: quadrant)
            return NSItemProvider(object: task.id.uuidString as NSString)
        } preview: {
            MatrixTaskDragPreview(title: task.title)
        }
    }

    private var quadrantDropBackground: some View {
        Rectangle()
            .fill(
                dragState.isTargeting(quadrant: quadrant)
                    ? quadrant.accentColor.opacity(0.12)
                    : .clear
            )
    }

    @ViewBuilder
    private var placeholderOverlay: some View {
        if let metrics = placeholderMetrics {
            MatrixDropPlaceholderView()
                .frame(width: metrics.width, height: placeholderHeight)
                .offset(x: metrics.origin.x, y: metrics.origin.y)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        }
    }

    private var placeholderMetrics: MatrixPlaceholderMetrics? {
        guard dragState.isTargeting(quadrant: quadrant), !contentFrame.equalTo(.zero), !tasks.isEmpty else { return nil }

        let sortedFrames = sortedTaskFrames
        let isTopInsertionTarget = dragState.dropTarget?.beforeTaskID == sortedFrames.first?.id
        guard !isTopInsertionTarget else { return nil }

        let centerY: CGFloat

        if let beforeTaskID = dragState.dropTarget?.beforeTaskID,
           let beforeFrame = taskFrames[beforeTaskID] {
            centerY = beforeFrame.minY - (rowSpacing / 2)
        } else if let lastFrame = sortedFrames.last?.frame {
            centerY = lastFrame.maxY + (rowSpacing / 2)
        } else {
            centerY = contentFrame.minY + (placeholderHeight / 2)
        }

        let minCenterY = contentFrame.minY + (placeholderHeight / 2)
        let maxCenterY = max(minCenterY, contentFrame.maxY - (placeholderHeight / 2))
        let clampedCenterY = min(max(centerY, minCenterY), maxCenterY)

        return MatrixPlaceholderMetrics(
            origin: CGPoint(x: contentFrame.minX, y: clampedCenterY - (placeholderHeight / 2)),
            width: contentFrame.width
        )
    }

    private var sortedTaskFrames: [(id: UUID, frame: CGRect)] {
        taskFrames
            .map { ($0.key, $0.value) }
            .sorted { lhs, rhs in
                lhs.frame.minY < rhs.frame.minY
            }
    }

    private var dropCoordinateSpaceID: String {
        "quadrant-drop-\(quadrant.rawValue)"
    }

    private var contentFrameReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: MatrixContentFramePreferenceKey.self,
                value: proxy.frame(in: .named(dropCoordinateSpaceID))
            )
        }
    }

    private func taskFrameReader(for taskID: UUID) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: MatrixTaskFramePreferenceKey.self,
                value: [taskID: proxy.frame(in: .named(dropCoordinateSpaceID))]
            )
        }
    }

    private func l(_ key: String) -> String {
        AppLocalizer.string(key, locale: locale)
    }
}

private struct QuickAddButton: View {
    let accent: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        if #available(macOS 26.0, *) {
            Button(action: action) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
                    .frame(width: 12, height: 12)
                    .padding(4)
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .buttonBorderShape(.circle)
            .tint(accent)
            .controlSize(.small)
            .keepsActiveControlAppearance()
        } else {
            Button(action: action) {
                Circle()
                    .fill(accent.opacity(isHovering ? 0.98 : 0.88))
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle()
                            .stroke(accent.opacity(isHovering ? 0.34 : 0.18), lineWidth: 1)
                    }
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.98))
                    }
                    .shadow(color: accent.opacity(isHovering ? 0.22 : 0.14), radius: 6, y: 2)
                    .scaleEffect(isHovering ? 1.08 : 1)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.2, dampingFraction: 0.86), value: isHovering)
            .onHover { inside in
                isHovering = inside
            }
        }
    }
}

private struct ActiveControlAppearanceModifier: ViewModifier {
    func body(content: Content) -> some View {
        // Keep native controls visually "alive" even when the window is not key.
        content.environment(\.controlActiveState, .key)
    }
}

private extension View {
    func keepsActiveControlAppearance() -> some View {
        modifier(ActiveControlAppearanceModifier())
    }
}

private struct MatrixTaskRow: View {
    @Environment(\.locale) private var locale

    let task: TaskItem
    let accent: Color
    let isBeingDragged: Bool
    let onCompleteTask: () -> Void
    let onOpenTask: () -> Void
    let onDeleteTask: () -> Void

    @State private var isHovering = false
    @State private var completionState: MatrixTaskCompletionState = .idle

    var body: some View {
        Button(action: triggerCompletion) {
            HStack(alignment: .center, spacing: 10) {
                completionIndicator

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(AppFont.bodySemibold)
                        .foregroundStyle(.primary)
                        .strikethrough(completionState != .idle, color: AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                        .opacity(textOpacity)
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(MatrixTaskRowButtonStyle())
        .opacity(rowOpacity)
        .blur(radius: completionState == .fading ? 7 : 0)
        .offset(y: completionState == .fading ? 22 : 0)
        .scaleEffect(isBeingDragged ? 0.992 : 1)
        .saturation(isBeingDragged ? 0.18 : 1)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: onOpenTask) {
                Label(l("task.edit"), systemImage: "pencil")
            }

            Button(role: .destructive, action: onDeleteTask) {
                Label(l("common.delete"), systemImage: "trash")
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.9), value: completionState)
        .animation(.easeInOut(duration: 0.12), value: isHovering)
        .animation(.easeInOut(duration: 0.12), value: isBeingDragged)
        .onHover { inside in
            isHovering = inside
        }
        .onAppear {
            completionState = .idle
        }
    }

    private var completionIndicator: some View {
        ZStack {
            Circle()
                .stroke(indicatorStrokeColor, lineWidth: 1.6)
                .background {
                    Circle()
                        .fill(indicatorFillColor)
                }
                .frame(width: 18, height: 18)

            if completionState == .armed || completionState == .fading {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.selectedText)
                    .transition(.scale.combined(with: .opacity))
            } else if !isBeingDragged && isHovering {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accent)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 18, height: 18)
    }

    private var indicatorStrokeColor: Color {
        if isBeingDragged {
            return AppTheme.tertiaryText.opacity(isHovering ? 0.84 : 0.7)
        }

        return completionState == .idle ? accent.opacity(isHovering ? 0.92 : 0.72) : accent
    }

    private var indicatorFillColor: Color {
        if completionState == .armed || completionState == .fading {
            return accent
        }

        if isBeingDragged {
            return AppTheme.quaternaryText.opacity(0.14)
        }

        return .clear
    }

    private var rowOpacity: Double {
        if completionState == .fading {
            return 0.02
        }

        return isBeingDragged ? 0.8 : 1
    }

    private var textOpacity: Double {
        if completionState == .fading {
            return 0.42
        }

        return isBeingDragged ? 0.84 : 1
    }

    private func triggerCompletion() {
        guard completionState == .idle else { return }

        let strikePause: TimeInterval = 0.12
        let fadeDuration: TimeInterval = 0.18
        let removalDelay: TimeInterval = 0.16

        withAnimation(.spring(response: 0.22, dampingFraction: 0.92)) {
            completionState = .armed
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + strikePause) {
            TaskCompletionFeedback.play()

            withAnimation(.easeInOut(duration: fadeDuration)) {
                completionState = .fading
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + removalDelay) {
                onCompleteTask()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                completionState = .idle
            }
        }
    }

    private func l(_ key: String) -> String {
        AppLocalizer.string(key, locale: locale)
    }
}

private struct MatrixTaskDragPreview: View {
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .stroke(AppTheme.tertiaryText.opacity(0.68), lineWidth: 1.5)
                .background {
                    Circle()
                        .fill(AppTheme.quaternaryText.opacity(0.1))
                }
                .frame(width: 16, height: 16)

            Text(title)
                .font(AppFont.bodySemibold)
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .frame(width: 220, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.rowFill.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.mutedBorder.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }
}

private struct MatrixDropPlaceholderView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(AppTheme.tertiaryText.opacity(0.9))
                .frame(width: 5, height: 5)

            Capsule()
                .fill(AppTheme.tertiaryText.opacity(0.78))
                .frame(height: 2)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MatrixPlaceholderMetrics {
    let origin: CGPoint
    let width: CGFloat
}

private struct MatrixTaskFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct MatrixContentFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.equalTo(.zero) {
            value = next
        }
    }
}

private enum MatrixTaskCompletionState {
    case idle
    case armed
    case fading
}

@MainActor
private final class MatrixBoardDragState: ObservableObject {
    struct DropTarget: Equatable {
        let quadrant: TaskQuadrant
        let beforeTaskID: UUID?
    }

    @Published private(set) var draggedTaskID: UUID?
    @Published private(set) var sourceQuadrant: TaskQuadrant?
    @Published private(set) var dropTarget: DropTarget?

    private var localMouseUpMonitor: Any?
    private var globalMouseUpMonitor: Any?

    var isDragging: Bool {
        draggedTaskID != nil
    }

    func beginDragging(taskID: UUID, from quadrant: TaskQuadrant) {
        removeMouseUpMonitors()

        draggedTaskID = taskID
        sourceQuadrant = quadrant
        dropTarget = nil

        installMouseUpMonitors()
    }

    func updateTarget(quadrant: TaskQuadrant, before beforeTaskID: UUID?) {
        guard let draggedTaskID else { return }

        guard beforeTaskID != draggedTaskID else {
            guard dropTarget != nil else { return }
            withAnimation(.easeInOut(duration: 0.1)) {
                dropTarget = nil
            }
            return
        }

        let nextTarget = DropTarget(quadrant: quadrant, beforeTaskID: beforeTaskID)
        guard dropTarget != nextTarget else { return }

        withAnimation(.easeInOut(duration: 0.12)) {
            dropTarget = nextTarget
        }
    }

    func isDragging(taskID: UUID) -> Bool {
        draggedTaskID == taskID
    }

    func isTargeting(quadrant: TaskQuadrant) -> Bool {
        dropTarget?.quadrant == quadrant
    }

    func shouldShowPlaceholder(in quadrant: TaskQuadrant, before beforeTaskID: UUID?) -> Bool {
        guard draggedTaskID != nil else { return false }
        return dropTarget == DropTarget(quadrant: quadrant, beforeTaskID: beforeTaskID)
    }

    func finishDragging() {
        reset(animated: true)
    }

    func clearTarget(in quadrant: TaskQuadrant) {
        guard dropTarget?.quadrant == quadrant else { return }

        withAnimation(.easeInOut(duration: 0.1)) {
            dropTarget = nil
        }
    }

    private func installMouseUpMonitors() {
        let eventMask: NSEvent.EventTypeMask = [.leftMouseUp, .rightMouseUp, .otherMouseUp]

        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.scheduleResetFromMonitor()
            return event
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] _ in
            self?.scheduleResetFromMonitor()
        }
    }

    private func scheduleResetFromMonitor() {
        guard draggedTaskID != nil else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.draggedTaskID != nil else { return }
            self.reset(animated: true)
        }
    }

    private func reset(animated: Bool) {
        removeMouseUpMonitors()

        let clearState = {
            self.draggedTaskID = nil
            self.sourceQuadrant = nil
            self.dropTarget = nil
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.14)) {
                clearState()
            }
        } else {
            clearState()
        }
    }

    private func removeMouseUpMonitors() {
        if let localMouseUpMonitor {
            NSEvent.removeMonitor(localMouseUpMonitor)
            self.localMouseUpMonitor = nil
        }

        if let globalMouseUpMonitor {
            NSEvent.removeMonitor(globalMouseUpMonitor)
            self.globalMouseUpMonitor = nil
        }
    }
}

private struct MatrixTaskDropDelegate: DropDelegate {
    let quadrant: TaskQuadrant
    let dragState: MatrixBoardDragState
    let rowFrames: [UUID: CGRect]
    let contentFrame: CGRect
    let onPerformDrop: (UUID, UUID?) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        dragState.draggedTaskID != nil
    }

    func dropEntered(info: DropInfo) {
        dragState.updateTarget(
            quadrant: quadrant,
            before: targetBeforeTaskID(for: info.location)
        )
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        dragState.updateTarget(
            quadrant: quadrant,
            before: targetBeforeTaskID(for: info.location)
        )
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedTaskID = dragState.draggedTaskID else { return false }
        let targetBeforeTaskID = targetBeforeTaskID(for: info.location)

        let dropCommitDelay: TimeInterval = 0.09

        DispatchQueue.main.asyncAfter(deadline: .now() + dropCommitDelay) {
            dragState.finishDragging()
            onPerformDrop(draggedTaskID, targetBeforeTaskID)
        }

        return true
    }

    func dropExited(info: DropInfo) {
        dragState.clearTarget(in: quadrant)
    }

    private func targetBeforeTaskID(for location: CGPoint) -> UUID? {
        let sortedFrames = rowFrames
            .map { ($0.key, $0.value) }
            .sorted { lhs, rhs in
                lhs.1.minY < rhs.1.minY
            }

        guard !sortedFrames.isEmpty else { return nil }

        let y = min(max(location.y, contentFrame.minY), contentFrame.maxY)

        for (taskID, frame) in sortedFrames {
            if y < frame.midY {
                return taskID
            }
        }

        return nil
    }
}

@MainActor
private enum TaskCompletionFeedback {
    private static let completionSound: NSSound? = {
        if let customURL = AppResources.bundle.url(forResource: "task-complete", withExtension: "mp3"),
           let customSound = NSSound(contentsOf: customURL, byReference: false) {
            return customSound
        }

        return ["Tink", "Pop", "Glass"]
            .lazy
            .compactMap { NSSound(named: NSSound.Name($0)) }
            .first
    }()

    static func play() {
        completionSound?.stop()
        completionSound?.play()
    }
}

private struct MatrixTaskRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 11)
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
