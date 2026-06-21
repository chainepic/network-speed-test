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
        name: "Advanced demo mode",
        priceRMB: 18,
        monthlyCredits: 30,
        benefits: [
            MembershipBenefit(
                id: "premium-global-nodes",
                title: "Unlock premium global nodes",
                details: "Expand from core free regions to North America, Europe, South America, South Asia, East Asia, Middle East, and Africa."
            ),
            MembershipBenefit(
                id: "monthly-credits",
                title: "30 demo credits per month",
                details: "Useful for standard and extreme speed tests while demonstrating quota protection for high-traffic scenarios."
            ),
            MembershipBenefit(
                id: "extreme-speed-access",
                title: "Extreme speed test entry",
                details: "Keeps the extreme speed test entry and richer diagnostics, with room to plug in dedicated nodes later."
            ),
            MembershipBenefit(
                id: "history-reports",
                title: "History and comparison",
                details: "Future support for saving each diagnosis run to compare VPN on/off, different networks, and regional changes."
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
            name: "Starter credit pack",
            priceRMB: 12,
            credits: 24,
            appleFeeRate: 0.15
        ),
        profiles: [
            MeteredTestProfile(
                id: "latency-map",
                name: "Global latency map",
                category: .free,
                downloadMegabytes: 1,
                uploadIngressMegabytes: 0,
                creditsRequired: 0,
                dailyHardLimit: nil,
                description: "Light ping/HTTP probes only. Safe to keep open by default."
            ),
            MeteredTestProfile(
                id: "standard-speed",
                name: "Standard speed test",
                category: .standard,
                downloadMegabytes: 100,
                uploadIngressMegabytes: 30,
                creditsRequired: 1,
                dailyHardLimit: 20,
                description: "Everyday download, upload, latency, and jitter results."
            ),
            MeteredTestProfile(
                id: "extreme-speed",
                name: "Extreme speed test",
                category: .extreme,
                downloadMegabytes: 250,
                uploadIngressMegabytes: 50,
                creditsRequired: 3,
                dailyHardLimit: 5,
                description: "Higher-traffic profile with stricter daily limits to protect public or self-hosted nodes."
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
