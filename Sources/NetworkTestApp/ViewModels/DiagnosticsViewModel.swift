import Foundation

@MainActor
final class DiagnosticsViewModel: ObservableObject {
    @Published var ipInfo: IPInfo?
    @Published var pathSnapshot: NetworkPathSnapshot = .unknown
    @Published var speedResult: SpeedTestResult?
    @Published var regionResults: [RegionProbeResult] = []
    @Published var diagnosis = DiagnosisSummary(
        title: "尚未开始诊断",
        details: "点击开始诊断后，会同时查询公网 IP、网络路径、基础测速和全球区域节点。",
        severity: .unknown
    )
    @Published var isRunning = false
    @Published var statusMessage = "Ready"
    @Published var progressSteps: [DiagnosticProgressStep] = []
    @Published var lastSpeedProfileName = "基础测速"

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
        statusMessage = "正在准备诊断..."
        progressSteps = Self.initialProgressSteps()

        Task {
            updateProgressStep("path", status: .running, details: "正在读取系统网络路径、接口类型和 VPN 线索。")
            let path = await pathService.currentSnapshot()
            pathSnapshot = path
            updateProgressStep("path", status: .completed, details: "已获取网络状态、接口、DNS、IPv4/IPv6 和 VPN 线索。")

            updateProgressStep("ip", status: .running, details: "正在查询公网 IP、地理位置和运营商。")
            let ip = await ipLookupService.lookup()
            ipInfo = ip
            let ipLookupFailed = ip.ipAddress == "Unavailable"
            updateProgressStep("ip", status: ipLookupFailed ? .failed : .completed, details: ipLookupFailed ? "公网 IP 查询失败，后续诊断会继续进行。" : "已获取公网 IP、位置和运营商信息。")

            updateProgressStep("speed", status: .running, details: "正在测试下载、上传、延迟和抖动。")
            lastSpeedProfileName = "基础测速"
            let speed = await speedTestService.runSpeedTest()
            speedResult = speed
            updateProgressStep("speed", status: speed.errorMessage == nil ? .completed : .failed, details: speed.errorMessage ?? "基础测速已完成。")

            updateProgressStep("regions", status: .running, details: includePremiumRegions ? "正在探测全部全球节点的可达性和延迟。" : "正在探测默认全球节点的可达性和延迟。")
            let regions = await regionalProbeService.probeRegions(includePremium: includePremiumRegions)
            regionResults = regions
            updateProgressStep("regions", status: .completed, details: "已完成 \(regions.count) 个全球节点探测。")

            updateProgressStep("summary", status: .running, details: "正在综合 IP、测速、路径和区域结果生成结论。")
            diagnosis = diagnosisEngine.summarize(
                ipInfo: ip,
                path: path,
                speed: speed,
                regions: regions
            )
            updateProgressStep("summary", status: .completed, details: "诊断结论和处理建议已生成。")
            statusMessage = "诊断完成"
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
        statusMessage = "正在运行 \(profile.name)..."

        Task {
            let speed = await speedTestService.runSpeedTest(profile: profile)
            speedResult = speed
            statusMessage = speed.errorMessage == nil ? "\(profile.name) 完成" : "\(profile.name) 失败"
            isRunning = false
            completion(speed)
        }
    }

    private func updateProgressStep(_ id: String, status: DiagnosticStepStatus, details: String) {
        guard let index = progressSteps.firstIndex(where: { $0.id == id }) else { return }
        progressSteps[index].status = status
        progressSteps[index].details = details
        statusMessage = progressSteps[index].title
    }

    private static func initialProgressSteps() -> [DiagnosticProgressStep] {
        [
            DiagnosticProgressStep(id: "path", title: "检查本机网络路径", details: "等待开始", status: .pending),
            DiagnosticProgressStep(id: "ip", title: "查询公网 IP", details: "等待开始", status: .pending),
            DiagnosticProgressStep(id: "speed", title: "执行基础测速", details: "等待开始", status: .pending),
            DiagnosticProgressStep(id: "regions", title: "探测全球节点", details: "等待开始", status: .pending),
            DiagnosticProgressStep(id: "summary", title: "生成诊断结论", details: "等待开始", status: .pending)
        ]
    }
}
