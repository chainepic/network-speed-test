import Foundation

enum DiagnosisSeverity: String, Codable, Sendable {
    case good
    case warning
    case problem
    case unknown
}

struct DiagnosisSummary: Equatable, Sendable {
    var title: String
    var details: String
    var severity: DiagnosisSeverity
    var findings: [DiagnosticFinding] = []
    var recommendations: [RepairAction] = []
}

struct DiagnosticFinding: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var details: String
    var impact: String
    var severity: DiagnosisSeverity
}

struct RepairAction: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var details: String
}

enum DiagnosticStepStatus: Equatable, Sendable {
    case pending
    case running
    case completed
    case failed
}

struct DiagnosticProgressStep: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var details: String
    var status: DiagnosticStepStatus
}

struct IPInfo: Equatable, Sendable {
    var ipAddress: String
    var city: String?
    var region: String?
    var country: String?
    var isp: String?
    var organization: String?
    var timezone: String?
    var source: String

    var locationDescription: String {
        [city, region, country]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: ", ")
    }
}

struct NetworkPathSnapshot: Equatable, Sendable {
    var status: String
    var interfaces: [String]
    var isExpensive: Bool
    var isConstrained: Bool
    var supportsIPv4: Bool
    var supportsIPv6: Bool
    var supportsDNS: Bool
    var likelyUsesVPN: Bool

    static let unknown = NetworkPathSnapshot(
        status: "Unknown",
        interfaces: [],
        isExpensive: false,
        isConstrained: false,
        supportsIPv4: false,
        supportsIPv6: false,
        supportsDNS: false,
        likelyUsesVPN: false
    )
}

struct SpeedTestResult: Equatable, Sendable {
    var downloadMbps: Double?
    var uploadMbps: Double?
    var latencyMilliseconds: Double?
    var jitterMilliseconds: Double?
    var samples: [Double]
    var endpointName: String
    var completedAt: Date
    var errorMessage: String?
}

struct RegionProbeResult: Identifiable, Equatable, Sendable {
    var id: String { regionCode }
    var regionCode: String
    var displayName: String
    var endpointHost: String
    var latencyMilliseconds: Double?
    var downloadMbps: Double?
    var isReachable: Bool
    var errorMessage: String?
    var requiresMembership: Bool = false
}

struct TestEndpoint: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case ipLookup
        case download(bytes: Int)
        case upload(bytes: Int)
        case regionalProbe
    }

    var id: String
    var name: String
    var regionCode: String?
    var url: URL
    var kind: Kind
    var requiresMembership: Bool = false
}

struct MembershipBenefit: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var details: String
}

struct MembershipPlan: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var priceRMB: Double
    var monthlyCredits: Int
    var benefits: [MembershipBenefit]

    static let pro = MembershipPlan(
        id: "pro-monthly",
        name: "高级演示模式",
        priceRMB: 18,
        monthlyCredits: 30,
        benefits: [
            MembershipBenefit(
                id: "premium-global-nodes",
                title: "解锁高级全球节点",
                details: "从免费核心节点扩展到北美、欧洲、南美、南亚、东亚、中东和非洲等更多区域。"
            ),
            MembershipBenefit(
                id: "monthly-credits",
                title: "每月 30 点演示额度",
                details: "可用于标准测速和极限测速，演示高流量测速的限额保护。"
            ),
            MembershipBenefit(
                id: "extreme-speed-access",
                title: "极限测速优先入口",
                details: "保留极限测速入口和更高价值的诊断结果，后续可接入专属测速节点。"
            ),
            MembershipBenefit(
                id: "history-reports",
                title: "历史报告与对比",
                details: "后续保存每次诊断结果，用来对比 VPN 开关、不同网络和不同地区的变化。"
            )
        ]
    )
}

enum MeteredTestCategory: String, Sendable {
    case free
    case standard
    case extreme
}

struct MeteredTestProfile: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var category: MeteredTestCategory
    var downloadMegabytes: Double
    var uploadIngressMegabytes: Double
    var creditsRequired: Int
    var dailyHardLimit: Int?
    var description: String

    func estimatedEgressCostRMB(perTerabyteUSD: Double, usdToRMB: Double) -> Double {
        downloadMegabytes / 1_000_000 * perTerabyteUSD * usdToRMB
    }

    func netRevenueRMB(perCreditRMB: Double) -> Double {
        Double(creditsRequired) * perCreditRMB
    }

    func grossMarginRMB(perTerabyteUSD: Double, usdToRMB: Double, perCreditRMB: Double) -> Double {
        netRevenueRMB(perCreditRMB: perCreditRMB) - estimatedEgressCostRMB(perTerabyteUSD: perTerabyteUSD, usdToRMB: usdToRMB)
    }

    func grossMarginRate(perTerabyteUSD: Double, usdToRMB: Double, perCreditRMB: Double) -> Double? {
        let revenue = netRevenueRMB(perCreditRMB: perCreditRMB)
        guard revenue > 0 else { return nil }
        let margin = grossMarginRMB(perTerabyteUSD: perTerabyteUSD, usdToRMB: usdToRMB, perCreditRMB: perCreditRMB)
        return margin / revenue
    }
}

struct CreditPack: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var priceRMB: Double
    var credits: Int
    var appleFeeRate: Double

    var netRevenueRMB: Double {
        priceRMB * (1 - appleFeeRate)
    }

    var netRevenuePerCreditRMB: Double {
        netRevenueRMB / Double(credits)
    }
}

enum CreditTransactionKind: String, Codable, Sendable {
    case purchase
    case membershipGrant
    case speedTestDebit
    case speedTestRefund
}

struct CreditTransaction: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: CreditTransactionKind
    var profileID: String?
    var title: String
    var creditsDelta: Int
    var createdAt: Date
    var note: String
}

struct CostProtectionPolicy: Equatable, Sendable {
    var worstCaseEgressCostPerTerabyteUSD: Double
    var usdToRMB: Double
    var minimumGrossMarginRate: Double
    var defaultCreditPack: CreditPack
    var profiles: [MeteredTestProfile]

    static let productionSafe = CostProtectionPolicy(
        worstCaseEgressCostPerTerabyteUSD: 90,
        usdToRMB: 7.2,
        minimumGrossMarginRate: 0.8,
        defaultCreditPack: CreditPack(
            id: "starter-credits",
            name: "安全额度包",
            priceRMB: 12,
            credits: 24,
            appleFeeRate: 0.15
        ),
        profiles: [
            MeteredTestProfile(
                id: "latency-map",
                name: "全球延迟地图",
                category: .free,
                downloadMegabytes: 1,
                uploadIngressMegabytes: 0,
                creditsRequired: 0,
                dailyHardLimit: nil,
                description: "只做 ping/HTTP 轻探测，适合默认开放。"
            ),
            MeteredTestProfile(
                id: "standard-speed",
                name: "标准测速",
                category: .standard,
                downloadMegabytes: 100,
                uploadIngressMegabytes: 30,
                creditsRequired: 1,
                dailyHardLimit: 20,
                description: "用于日常下载、上传、延迟、抖动结果展示。"
            ),
            MeteredTestProfile(
                id: "extreme-speed",
                name: "极限测速",
                category: .extreme,
                downloadMegabytes: 250,
                uploadIngressMegabytes: 50,
                creditsRequired: 3,
                dailyHardLimit: 5,
                description: "高带宽场景使用更高额度并限制每日次数，避免滥用公共或自建节点。"
            )
        ]
    )

    var netRevenuePerCreditRMB: Double {
        defaultCreditPack.netRevenuePerCreditRMB
    }

    var standardSpeedProfile: MeteredTestProfile? {
        profiles.first { $0.category == .standard }
    }

    var extremeSpeedProfile: MeteredTestProfile? {
        profiles.first { $0.category == .extreme }
    }

    var paidSpeedProfiles: [MeteredTestProfile] {
        profiles.filter { $0.category == .standard || $0.category == .extreme }
    }

    func isProfitProtected(_ profile: MeteredTestProfile) -> Bool {
        guard profile.creditsRequired > 0 else { return true }
        let revenue = profile.netRevenueRMB(perCreditRMB: netRevenuePerCreditRMB)
        let cost = profile.estimatedEgressCostRMB(
            perTerabyteUSD: worstCaseEgressCostPerTerabyteUSD,
            usdToRMB: usdToRMB
        )
        guard revenue > 0 else { return false }
        return (revenue - cost) / revenue >= minimumGrossMarginRate
    }
}

extension Double {
    var formattedMbps: String {
        String(format: "%.1f Mbps", self)
    }

    var formattedMilliseconds: String {
        String(format: "%.0f ms", self)
    }

    var formattedRMB: String {
        String(format: "¥%.2f", self)
    }

    var formattedPercent: String {
        String(format: "%.1f%%", self * 100)
    }
}
