import Foundation

@MainActor
final class DiagnosticsViewModel: ObservableObject {
    @Published var ipInfo: IPInfo?
    @Published var pathSnapshot: NetworkPathSnapshot = .unknown
    @Published var speedResult: SpeedTestResult?
    @Published var regionResults: [RegionProbeResult] = []
    @Published var diagnosis = DiagnosisSummary(
        title: "Diagnostics not started",
        details: "Run diagnostics to query public IP, network path, baseline speed, and global regional nodes.",
        severity: .unknown
    )
    @Published var isRunning = false
    @Published var statusMessage = "Ready"
    @Published var progressSteps: [DiagnosticProgressStep] = []
    @Published var lastSpeedProfileName = "Baseline speed test"

    private let ipLookupService: IPLookupServicing
    private let pathService: NetworkPathServicing
    private let speedTestService: SpeedTestServicing
    private let regionalProbeService: RegionalProbeServicing
    private let diagnosisEngine: DiagnosisEngine

    init(
        ipLookupService: IPLookupServicing = IPLookupService(),
        pathService: NetworkPathServicing = NetworkPathService(),
        speedTestService: SpeedTestServicing = SpeedTestService(),
        regionalProbeService: RegionalProbeServicing = RegionalProbeService(),
        diagnosisEngine: DiagnosisEngine = DiagnosisEngine()
    ) {
        self.ipLookupService = ipLookupService
        self.pathService = pathService
        self.speedTestService = speedTestService
        self.regionalProbeService = regionalProbeService
        self.diagnosisEngine = diagnosisEngine
        self.progressSteps = Self.initialProgressSteps()
    }

    func runFullDiagnosis(includePremiumRegions: Bool = false) {
        guard isRunning == false else { return }

        isRunning = true
        statusMessage = "Preparing diagnostics..."
        progressSteps = Self.initialProgressSteps()

        Task {
            updateProgressStep("path", status: .running, details: "Reading system network path, interface types, and VPN clues.")
            let path = await pathService.currentSnapshot()
            pathSnapshot = path
            updateProgressStep("path", status: .completed, details: "Collected network status, interfaces, DNS, IPv4/IPv6, and VPN clues.")

            updateProgressStep("ip", status: .running, details: "Looking up public IP, location, and ISP.")
            let ip = await ipLookupService.lookup()
            ipInfo = ip
            let ipLookupFailed = ip.ipAddress == "Unavailable"
            updateProgressStep("ip", status: ipLookupFailed ? .failed : .completed, details: ipLookupFailed ? "Public IP lookup failed. Remaining checks will continue." : "Collected public IP, location, and ISP details.")

            updateProgressStep("speed", status: .running, details: "Testing download, upload, latency, and jitter.")
            lastSpeedProfileName = "Baseline speed test"
            let speed = await speedTestService.runSpeedTest()
            speedResult = speed
            updateProgressStep("speed", status: speed.errorMessage == nil ? .completed : .failed, details: speed.errorMessage ?? "Baseline speed test completed.")

            updateProgressStep("regions", status: .running, details: includePremiumRegions ? "Probing all global nodes for reachability and latency." : "Probing default global nodes for reachability and latency.")
            let regions = await regionalProbeService.probeRegions(includePremium: includePremiumRegions)
            regionResults = regions
            updateProgressStep("regions", status: .completed, details: "Completed probing \(regions.count) global nodes.")

            updateProgressStep("summary", status: .running, details: "Combining IP, speed, path, and regional results into a summary.")
            diagnosis = diagnosisEngine.summarize(
                ipInfo: ip,
                path: path,
                speed: speed,
                regions: regions
            )
            updateProgressStep("summary", status: .completed, details: "Diagnosis summary and recommendations are ready.")
            statusMessage = "Diagnostics complete"
            isRunning = false
        }
    }

    func runMeteredSpeedTest(
        profile: MeteredTestProfile,
        completion: @escaping (SpeedTestResult) -> Void = { _ in }
    ) {
        guard isRunning == false else { return }

        isRunning = true
        lastSpeedProfileName = profile.name
        statusMessage = "Running \(profile.name)..."

        Task {
            let speed = await speedTestService.runSpeedTest(profile: profile)
            speedResult = speed
            statusMessage = speed.errorMessage == nil ? "\(profile.name) complete" : "\(profile.name) failed"
            isRunning = false
            completion(speed)
        }
    }

    func loadScreenshotPreview(scenario: ScreenshotScenario) {
        ipInfo = scenario.ipInfo
        pathSnapshot = scenario.pathSnapshot
        speedResult = scenario.speedResult
        regionResults = scenario.regionResults
        diagnosis = scenario.diagnosis
        lastSpeedProfileName = scenario.speedProfileName
        statusMessage = "Diagnostics complete"
        progressSteps = scenario.progressSteps
    }

    private func updateProgressStep(_ id: String, status: DiagnosticStepStatus, details: String) {
        guard let index = progressSteps.firstIndex(where: { $0.id == id }) else { return }
        progressSteps[index].status = status
        progressSteps[index].details = details
        statusMessage = progressSteps[index].title
    }

    private static func initialProgressSteps() -> [DiagnosticProgressStep] {
        [
            DiagnosticProgressStep(id: "path", title: "Check local network path", details: "Waiting to start", status: .pending),
            DiagnosticProgressStep(id: "ip", title: "Look up public IP", details: "Waiting to start", status: .pending),
            DiagnosticProgressStep(id: "speed", title: "Run baseline speed test", details: "Waiting to start", status: .pending),
            DiagnosticProgressStep(id: "regions", title: "Probe global nodes", details: "Waiting to start", status: .pending),
            DiagnosticProgressStep(id: "summary", title: "Generate diagnosis summary", details: "Waiting to start", status: .pending)
        ]
    }
}

enum ScreenshotScenario {
    case overviewVPN
    case overviewLocalIssue
    case speedTest
    case globalNodes

    var ipInfo: IPInfo {
        switch self {
        case .overviewVPN:
            IPInfo(
                ipAddress: "74.211.106.65",
                city: "Los Angeles",
                region: "California",
                country: "United States",
                isp: "IT7 Networks Inc",
                organization: nil,
                timezone: "America/Los_Angeles",
                source: "ipapi.co"
            )
        case .overviewLocalIssue:
            IPInfo(
                ipAddress: "222.241.249.160",
                city: "Changsha",
                region: "Hunan",
                country: "China",
                isp: "Chinanet",
                organization: nil,
                timezone: "Asia/Shanghai",
                source: "ipapi.co"
            )
        default:
            IPInfo(
                ipAddress: "203.0.113.42",
                city: "Singapore",
                region: nil,
                country: "Singapore",
                isp: "Example Fiber",
                organization: nil,
                timezone: "Asia/Singapore",
                source: "ipapi.co"
            )
        }
    }

    var pathSnapshot: NetworkPathSnapshot {
        switch self {
        case .overviewVPN:
            NetworkPathSnapshot(
                status: "Online",
                interfaces: ["Wi-Fi", "Other"],
                isExpensive: false,
                isConstrained: false,
                supportsIPv4: true,
                supportsIPv6: false,
                supportsDNS: true,
                likelyUsesVPN: true
            )
        case .overviewLocalIssue:
            NetworkPathSnapshot(
                status: "Online",
                interfaces: ["Wi-Fi"],
                isExpensive: false,
                isConstrained: false,
                supportsIPv4: true,
                supportsIPv6: false,
                supportsDNS: true,
                likelyUsesVPN: true
            )
        default:
            NetworkPathSnapshot(
                status: "Online",
                interfaces: ["Wi-Fi"],
                isExpensive: false,
                isConstrained: false,
                supportsIPv4: true,
                supportsIPv6: true,
                supportsDNS: true,
                likelyUsesVPN: false
            )
        }
    }

    var speedResult: SpeedTestResult {
        switch self {
        case .overviewVPN, .speedTest:
            SpeedTestResult(
                downloadMbps: 30.2,
                uploadMbps: 0.9,
                latencyMilliseconds: 364,
                jitterMilliseconds: 201,
                samples: [30.2],
                endpointName: "Cloudflare 25 MB",
                completedAt: .now,
                errorMessage: nil
            )
        case .overviewLocalIssue:
            SpeedTestResult(
                downloadMbps: 3.1,
                uploadMbps: 0.1,
                latencyMilliseconds: 453,
                jitterMilliseconds: 335,
                samples: [3.1],
                endpointName: "Cloudflare 25 MB",
                completedAt: .now,
                errorMessage: nil
            )
        case .globalNodes:
            SpeedTestResult(
                downloadMbps: 286.4,
                uploadMbps: 42.8,
                latencyMilliseconds: 19,
                jitterMilliseconds: 4,
                samples: [286.4],
                endpointName: "Standard speed test / Cloudflare",
                completedAt: .now,
                errorMessage: nil
            )
        }
    }

    var regionResults: [RegionProbeResult] {
        switch self {
        case .globalNodes:
            [
                RegionProbeResult(regionCode: "AU", displayName: "Australia", endpointHost: "dynamodb.ap-southeast-2.amazonaws.com", latencyMilliseconds: 681, downloadMbps: nil, isReachable: true, errorMessage: nil),
                RegionProbeResult(regionCode: "JP", displayName: "Japan", endpointHost: "www.google.co.jp", latencyMilliseconds: 396, downloadMbps: nil, isReachable: true, errorMessage: nil),
                RegionProbeResult(regionCode: "SG", displayName: "Singapore", endpointHost: "www.google.com.sg", latencyMilliseconds: 369, downloadMbps: nil, isReachable: true, errorMessage: nil),
                RegionProbeResult(regionCode: "US-W", displayName: "US West", endpointHost: "dynamodb.us-west-1.amazonaws.com", latencyMilliseconds: nil, downloadMbps: nil, isReachable: false, errorMessage: "Failed"),
                RegionProbeResult(regionCode: "EU", displayName: "Europe", endpointHost: "dynamodb.eu-west-1.amazonaws.com", latencyMilliseconds: 1824, downloadMbps: nil, isReachable: true, errorMessage: nil),
                RegionProbeResult(regionCode: "CN", displayName: "Mainland China", endpointHost: "www.baidu.com", latencyMilliseconds: 3797, downloadMbps: nil, isReachable: true, errorMessage: nil),
                RegionProbeResult(regionCode: "US-E", displayName: "US East", endpointHost: "dynamodb.us-east-1.amazonaws.com", latencyMilliseconds: 2132, downloadMbps: nil, isReachable: true, errorMessage: nil)
            ]
        case .overviewVPN:
            [
                RegionProbeResult(regionCode: "US-W", displayName: "US West", endpointHost: "dynamodb.us-west-1.amazonaws.com", latencyMilliseconds: 943, downloadMbps: nil, isReachable: true, errorMessage: nil),
                RegionProbeResult(regionCode: "US-E", displayName: "US East", endpointHost: "dynamodb.us-east-1.amazonaws.com", latencyMilliseconds: 937, downloadMbps: nil, isReachable: true, errorMessage: nil),
                RegionProbeResult(regionCode: "EU", displayName: "Europe", endpointHost: "dynamodb.eu-west-1.amazonaws.com", latencyMilliseconds: 1201, downloadMbps: nil, isReachable: true, errorMessage: nil),
                RegionProbeResult(regionCode: "JP", displayName: "Japan", endpointHost: "www.google.co.jp", latencyMilliseconds: 1073, downloadMbps: nil, isReachable: true, errorMessage: nil),
                RegionProbeResult(regionCode: "SG", displayName: "Singapore", endpointHost: "www.google.com.sg", latencyMilliseconds: 1295, downloadMbps: nil, isReachable: true, errorMessage: nil),
                RegionProbeResult(regionCode: "AU", displayName: "Australia", endpointHost: "dynamodb.ap-southeast-2.amazonaws.com", latencyMilliseconds: 1213, downloadMbps: nil, isReachable: true, errorMessage: nil),
                RegionProbeResult(regionCode: "CN", displayName: "Mainland China", endpointHost: "www.baidu.com", latencyMilliseconds: 1371, downloadMbps: nil, isReachable: true, errorMessage: nil)
            ]
        default:
            []
        }
    }

    var diagnosis: DiagnosisSummary {
        DiagnosisEngine().summarize(
            ipInfo: ipInfo,
            path: pathSnapshot,
            speed: speedResult,
            regions: regionResults
        )
    }

    var speedProfileName: String {
        switch self {
        case .speedTest:
            "Standard speed test"
        case .globalNodes:
            "Standard speed test"
        default:
            "Baseline speed test"
        }
    }

    var progressSteps: [DiagnosticProgressStep] {
        [
            DiagnosticProgressStep(id: "path", title: "Check local network path", details: "Collected network status, interfaces, DNS, IPv4/IPv6, and VPN clues.", status: .completed),
            DiagnosticProgressStep(id: "ip", title: "Look up public IP", details: "Collected public IP, location, and ISP details.", status: .completed),
            DiagnosticProgressStep(id: "speed", title: "Run baseline speed test", details: "Baseline speed test completed.", status: .completed),
            DiagnosticProgressStep(id: "regions", title: "Probe global nodes", details: "Completed probing global nodes.", status: .completed),
            DiagnosticProgressStep(id: "summary", title: "Generate diagnosis summary", details: "Diagnosis summary and recommendations are ready.", status: .completed)
        ]
    }
}

enum AppPreviewData {
    static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] == "1"
    }

    static var screenshotScenario: ScreenshotScenario {
        switch ProcessInfo.processInfo.environment["SCREENSHOT_SCENARIO"] {
        case "local-issue":
            .overviewLocalIssue
        case "speed-test":
            .speedTest
        case "global-nodes":
            .globalNodes
        default:
            .overviewVPN
        }
    }

    static var screenshotTab: Int {
        Int(ProcessInfo.processInfo.environment["SCREENSHOT_TAB"] ?? "0") ?? 0
    }
}
