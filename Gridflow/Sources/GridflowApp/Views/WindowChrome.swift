import AppKit
import SwiftUI

@MainActor
enum AppWindowChrome {
    static let minimumWindowSize = NSSize(width: 960, height: 640)
    static let defaultWindowSize = NSSize(width: 1220, height: 780)

    static func configure(
        _ window: NSWindow,
        enforceMinimumSize: Bool = false
    ) {
        window.title = ""
        window.subtitle = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified

        guard enforceMinimumSize else { return }

        window.minSize = minimumWindowSize
        window.contentMinSize = minimumWindowSize

        if window.frame.size.width < minimumWindowSize.width || window.frame.size.height < minimumWindowSize.height {
            window.setContentSize(defaultWindowSize)
            window.center()
        }
    }
}

struct WindowChromeReader: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}

extension View {
    func appWindowChrome() -> some View {
        background(
            WindowChromeReader { window in
                AppWindowChrome.configure(window)
            }
        )
    }
}
