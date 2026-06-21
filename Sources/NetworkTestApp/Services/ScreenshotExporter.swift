#if os(macOS)
import AppKit
import SwiftUI

enum ScreenshotExporter {
    struct ExportSpec: Sendable {
        var scenario: ScreenshotScenario
        var tab: Int
        var filename: String
    }

    static let defaultSpecs: [ExportSpec] = [
        ExportSpec(scenario: .overviewVPN, tab: 0, filename: "overview-vpn-detection.png"),
        ExportSpec(scenario: .overviewLocalIssue, tab: 0, filename: "overview-diagnosis.png"),
        ExportSpec(scenario: .overviewVPN, tab: 1, filename: "speed-test-results.png"),
        ExportSpec(scenario: .speedTest, tab: 1, filename: "speed-test-guardrails.png"),
        ExportSpec(scenario: .overviewVPN, tab: 2, filename: "global-nodes-latency.png"),
        ExportSpec(scenario: .globalNodes, tab: 2, filename: "global-nodes-mixed-results.png")
    ]

    @MainActor
    static func exportAll(to directory: URL, specs: [ExportSpec] = defaultSpecs) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for spec in specs {
            let outputURL = directory.appendingPathComponent(spec.filename)
            try export(spec, to: outputURL)
            print("Exported \(outputURL.path)")
        }
    }

    @MainActor
    private static func export(_ spec: ExportSpec, to outputURL: URL) throws {
        let size = NSSize(width: 980, height: 600)
        let view = DashboardView(previewScenario: spec.scenario, previewTab: spec.tab)
            .environment(\.screenshotPreview, true)
            .frame(width: size.width, height: size.height)

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw ExportError.renderFailed(spec.filename)
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)

        guard let tiffData = image.tiffRepresentation,
              let pngData = NSBitmapImageRep(data: tiffData)?.representation(using: .png, properties: [:]) else {
            throw ExportError.encodeFailed(spec.filename)
        }

        try pngData.write(to: outputURL)
    }

    enum ExportError: Error, CustomStringConvertible {
        case renderFailed(String)
        case encodeFailed(String)

        var description: String {
            switch self {
            case .renderFailed(let filename):
                "Failed to render screenshot for \(filename)"
            case .encodeFailed(let filename):
                "Failed to encode PNG for \(filename)"
            }
        }
    }
}

private struct ScreenshotPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var screenshotPreview: Bool {
        get { self[ScreenshotPreviewKey.self] }
        set { self[ScreenshotPreviewKey.self] = newValue }
    }
}
#endif
