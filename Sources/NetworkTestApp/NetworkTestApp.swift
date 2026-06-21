import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct NetworkTestApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        #if os(macOS)
        .defaultSize(width: 980, height: 600)
        #endif
    }
}

#if os(macOS)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["SCREENSHOT_EXPORT"] == "1" {
            let screenshotPath = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "docs/screenshots"
            let outputDirectory = screenshotPath.hasPrefix("/")
                ? URL(fileURLWithPath: screenshotPath, isDirectory: true)
                : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent(screenshotPath, isDirectory: true)

            do {
                try ScreenshotExporter.exportAll(to: outputDirectory)
            } catch {
                fputs("Screenshot export failed: \(error)\n", stderr)
                exit(1)
            }

            NSApp.terminate(nil)
            return
        }

        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first {
            window.minSize = NSSize(width: 920, height: 600)
            window.setContentSize(NSSize(width: 980, height: 600))
            window.makeKeyAndOrderFront(nil)
            window.center()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif
