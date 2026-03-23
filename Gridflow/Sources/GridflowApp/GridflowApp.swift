import AppKit
import SwiftUI

@main
struct GridflowDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsStore()
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .environment(\.locale, settings.locale)
                .preferredColorScheme(settings.themeMode.preferredColorScheme)
                .toggleStyle(LiquidGlassToggleStyle())
        }
        .windowStyle(.hiddenTitleBar)

        Window(AppMetadata.aboutWindowTitle, id: AppMetadata.aboutWindowID) {
            AboutView()
        }
        .windowResizability(.contentSize)

        .commands {
            GridflowCommands(settings: settings)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowBecameMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )

        DispatchQueue.main.async {
            for window in NSApp.windows {
                self.configureWindowAppearance(window)
            }
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    @objc
    private func handleWindowBecameMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        configureWindowAppearance(window)
    }

    private func configureWindowAppearance(_ window: NSWindow) {
        guard shouldManageWindow(window) else { return }
        AppWindowChrome.configure(window, enforceMinimumSize: true)
        window.delegate = self
    }

    private func shouldManageWindow(_ window: NSWindow) -> Bool {
        !(window is NSPanel) && window.sheetParent == nil
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard shouldManageWindow(sender) else { return frameSize }
        return NSSize(
            width: max(frameSize.width, AppWindowChrome.minimumWindowSize.width),
            height: max(frameSize.height, AppWindowChrome.minimumWindowSize.height)
        )
    }
}

private struct GridflowCommands: Commands {
    @ObservedObject var settings: SettingsStore
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(AppMetadata.aboutWindowTitle) {
                openWindow(id: AppMetadata.aboutWindowID)
            }
        }

        CommandGroup(replacing: .newItem) {
            Button(l("task.new")) {
                NotificationCenter.default.post(name: .newTaskCommand, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command])
        }

        CommandGroup(replacing: .undoRedo) {
            Button(l("commands.undo")) {
                NotificationCenter.default.post(name: .undoCommand, object: nil)
            }
            .keyboardShortcut("z", modifiers: [.command])
        }
    }

    private func l(_ key: String) -> String {
        AppLocalizer.string(key, locale: settings.locale)
    }
}
