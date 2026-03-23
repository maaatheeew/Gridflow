import AppKit
import SwiftUI

@MainActor
enum AppScrollViewChrome {
    static func applyThinStyle(to scrollView: NSScrollView) {
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.verticalScroller?.controlSize = .mini
        scrollView.horizontalScroller?.controlSize = .mini
    }

    static func applyInsetOverlayStyle(
        to scrollView: NSScrollView,
        verticalInset: CGFloat = 10,
        trailingInset: CGFloat = 10,
        contentTrailingInset: CGFloat = 16
    ) {
        applyThinStyle(to: scrollView)
        scrollView.hasVerticalScroller = true
        scrollView.scrollerInsets = NSEdgeInsets(
            top: verticalInset,
            left: 0,
            bottom: verticalInset,
            right: trailingInset
        )
        scrollView.contentInsets = NSEdgeInsets(
            top: 0,
            left: 0,
            bottom: 0,
            right: contentTrailingInset
        )
    }

    static func applyPersistentVerticalStyle(to scrollView: NSScrollView) {
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.verticalScroller?.controlSize = .mini
        scrollView.horizontalScroller?.controlSize = .mini
    }
}

struct ScrollViewChromeReader: NSViewRepresentable {
    let onResolve: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSView {
        context.coordinator.resolveScrollViewIfNeeded()
        return context.coordinator.view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.resolveScrollViewIfNeeded()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onResolve: onResolve)
    }

    @MainActor
    final class Coordinator: NSObject {
        let onResolve: (NSScrollView) -> Void
        let view = NSView()
        private var lastResolvedScrollViewID: ObjectIdentifier?
        private var isResolutionScheduled = false

        init(onResolve: @escaping (NSScrollView) -> Void) {
            self.onResolve = onResolve
        }

        func resolveScrollViewIfNeeded() {
            if let scrollView = view.enclosingScrollView {
                applyIfNeeded(to: scrollView)
                return
            }

            guard !isResolutionScheduled else { return }
            isResolutionScheduled = true

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                self.isResolutionScheduled = false

                guard let scrollView = self.view.enclosingScrollView else { return }
                self.applyIfNeeded(to: scrollView)
            }
        }

        private func applyIfNeeded(to scrollView: NSScrollView) {
            let scrollViewID = ObjectIdentifier(scrollView)
            guard lastResolvedScrollViewID != scrollViewID else { return }

            lastResolvedScrollViewID = scrollViewID
            onResolve(scrollView)
        }
    }
}
