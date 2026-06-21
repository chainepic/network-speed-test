import SwiftUI
import MapKit

struct DashboardView: View {
    @StateObject private var viewModel = DiagnosticsViewModel()
    @StateObject private var creditStore = CreditLedgerStore()
    @StateObject private var membershipStore = MembershipStore()
    @State private var selectedTab: Int
    private let previewScenario: ScreenshotScenario?
    private let costPolicy = CostProtectionPolicy.productionSafe

    init(previewScenario: ScreenshotScenario? = nil, previewTab: Int = 0) {
        self.previewScenario = previewScenario
        _selectedTab = State(initialValue: previewTab)

        let previewDefaults = UserDefaults(suiteName: "network-speed-test-screenshot")!
        previewDefaults.removePersistentDomain(forName: "network-speed-test-screenshot")

        let viewModel = DiagnosticsViewModel()
        let creditStore = CreditLedgerStore(userDefaults: previewScenario == nil ? .standard : previewDefaults)
        let membershipStore = MembershipStore(userDefaults: previewScenario == nil ? .standard : previewDefaults)

        if let previewScenario {
            viewModel.loadScreenshotPreview(scenario: previewScenario)
            if previewScenario == .speedTest {
                creditStore.loadScreenshotPreview()
            }
        }

        _viewModel = StateObject(wrappedValue: viewModel)
        _creditStore = StateObject(wrappedValue: creditStore)
        _membershipStore = StateObject(wrappedValue: membershipStore)
    }

    var body: some View {
        Group {
            if previewScenario != nil {
                VStack(spacing: 0) {
                    ScreenshotTabBar(selectedTab: selectedTab)
                    selectedTabContent
                }
            } else {
                TabView(selection: $selectedTab) {
                    tabContent
                }
            }
        }
        .frame(minWidth: 920, minHeight: 600)
        .onAppear {
            if let previewScenario {
                applyScreenshotPreview(scenario: previewScenario)
                return
            }

            guard AppPreviewData.isScreenshotMode else { return }
            applyScreenshotPreview(scenario: AppPreviewData.screenshotScenario)
            selectedTab = AppPreviewData.screenshotTab
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        DiagnosisOverviewTab(viewModel: viewModel, membershipStore: membershipStore)
            .tabItem {
                Label("Overview", systemImage: "gauge.with.dots.needle.bottom.50percent")
            }
            .tag(0)

        SpeedDiagnosticsTab(viewModel: viewModel, creditStore: creditStore, policy: costPolicy)
            .tabItem {
                Label("Speed Test", systemImage: "speedometer")
            }
            .tag(1)

        RegionResultsTab(results: viewModel.regionResults, membershipStore: membershipStore, creditStore: creditStore)
            .tabItem {
                Label("Global Nodes", systemImage: "map")
            }
            .tag(2)

        CostProtectionTab(policy: costPolicy, membershipStore: membershipStore, creditStore: creditStore)
            .tabItem {
                Label("Open Source Lab", systemImage: "shippingbox")
            }
            .tag(3)
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case 1:
            SpeedDiagnosticsTab(viewModel: viewModel, creditStore: creditStore, policy: costPolicy)
        case 2:
            RegionResultsTab(results: viewModel.regionResults, membershipStore: membershipStore, creditStore: creditStore)
        case 3:
            CostProtectionTab(policy: costPolicy, membershipStore: membershipStore, creditStore: creditStore)
        default:
            DiagnosisOverviewTab(viewModel: viewModel, membershipStore: membershipStore)
        }
    }

    private func applyScreenshotPreview(scenario: ScreenshotScenario) {
        viewModel.loadScreenshotPreview(scenario: scenario)
        if scenario == .speedTest {
            creditStore.loadScreenshotPreview()
        }
    }
}

private struct ScreenshotTabBar: View {
    var selectedTab: Int

    private let tabs = [
        ("Overview", "gauge.with.dots.needle.bottom.50percent"),
        ("Speed Test", "speedometer"),
        ("Global Nodes", "map"),
        ("Open Source Lab", "shippingbox")
    ]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Label(tab.0, systemImage: tab.1)
                    .font(.subheadline.weight(selectedTab == index ? .semibold : .regular))
                    .foregroundStyle(selectedTab == index ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedTab == index ? Color.secondary.opacity(0.16) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private struct DiagnosisOverviewTab: View {
    @ObservedObject var viewModel: DiagnosticsViewModel
    @ObservedObject var membershipStore: MembershipStore

    var body: some View {
        MacStyledScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    DiagnosisCard(summary: viewModel.diagnosis)
                        .layoutPriority(1)

                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            viewModel.runFullDiagnosis(includePremiumRegions: membershipStore.isPro)
                        } label: {
                            Label(viewModel.isRunning ? "Running..." : "Start network diagnostics", systemImage: "network")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(viewModel.isRunning)

                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        Text(membershipStore.isPro ? "This run will probe all \(EndpointCatalog.regional.count) global nodes" : "Default run probes \(EndpointCatalog.freeRegional.count) core nodes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 240)
                }

                DiagnosticProgressCard(steps: viewModel.progressSteps)

                CompactMembershipCard(membershipStore: membershipStore)

                HStack(alignment: .top, spacing: 12) {
                    IPInfoCard(info: viewModel.ipInfo)
                    NetworkPathCard(snapshot: viewModel.pathSnapshot)
                }

                HStack(alignment: .top, spacing: 12) {
                    FindingsCard(findings: viewModel.diagnosis.findings)
                    RecommendationsCard(actions: viewModel.diagnosis.recommendations)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

private struct SpeedDiagnosticsTab: View {
    @ObservedObject var viewModel: DiagnosticsViewModel
    @ObservedObject var creditStore: CreditLedgerStore
    var policy: CostProtectionPolicy

    var body: some View {
        MacStyledScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    SpeedResultCard(title: viewModel.lastSpeedProfileName, result: viewModel.speedResult)
                    CreditWalletCard(creditStore: creditStore, pack: policy.defaultCreditPack)
                }

                HStack(alignment: .top, spacing: 12) {
                    ForEach(policy.paidSpeedProfiles) { profile in
                        MeteredSpeedActionCard(
                            profile: profile,
                            creditStore: creditStore,
                            isRunning: viewModel.isRunning
                        ) {
                            run(profile)
                        }
                    }
                }

                CreditHistoryCard(transactions: creditStore.transactions)

                SpeedEndpointInfoCard()

                CardView(title: "Open-source demo notes") {
                    Text("This repo is a local-first open-source demo. Credits and history stay on-device to illustrate cost protection for high-traffic speed tests. When you connect self-hosted nodes, quota checks, refunds, daily limits, and signed test URLs should run on the server.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    InfoRow(label: "Reserve credits", value: "Credits are reserved before a test starts and refunded automatically on failure.")
                    InfoRow(label: "Short-lived URL", value: "Use one-time signed speed test URLs when a server is involved.")
                    InfoRow(label: "Abuse limits", value: "Local daily limits exist now; production should add account/device/IP throttling.")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func run(_ profile: MeteredTestProfile) {
        guard creditStore.consumeCredits(for: profile) else { return }

        viewModel.runMeteredSpeedTest(profile: profile) { result in
            if result.errorMessage != nil {
                creditStore.refundCredits(for: profile, reason: "Speed test request failed. Reserved credits were returned automatically.")
            }
        }
    }
}

private struct SpeedEndpointInfoCard: View {
    var body: some View {
        CardView(title: "Current speed test endpoints") {
            Text("Standard and extreme speed tests currently use third-party public endpoints rather than self-hosted infrastructure. Download and upload prefer Cloudflare Speed Test edge nodes; the actual city depends on Anycast routing and your network path.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            InfoRow(label: "Download", value: "speed.cloudflare.com/__down with 100 MB or 250 MB payloads by profile")
            InfoRow(label: "Upload", value: "speed.cloudflare.com/__up with 30 MB or 50 MB payloads by profile")
            InfoRow(label: "Fallback", value: "httpbin.org/post remains as a public upload fallback when Cloudflare upload fails.")
            InfoRow(label: "Global nodes", value: "The global nodes tab probes regional endpoints from Google/Baidu and AWS DynamoDB.")
        }
    }
}

private struct CreditWalletCard: View {
    @ObservedObject var creditStore: CreditLedgerStore
    var pack: CreditPack

    var body: some View {
        CardView(title: "Test credits") {
            InfoRow(label: "Balance", value: "\(creditStore.balance) credits")
            InfoRow(label: "Demo top-up", value: "\(pack.priceRMB.formattedRMB) / \(pack.credits) credits")

            Button {
                creditStore.addCredits(from: pack)
            } label: {
                Label("Add demo credits", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text(creditStore.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MeteredSpeedActionCard: View {
    var profile: MeteredTestProfile
    @ObservedObject var creditStore: CreditLedgerStore
    var isRunning: Bool
    var run: () -> Void

    var body: some View {
        CardView(title: profile.name) {
            Text(profile.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            InfoRow(label: "Cost", value: "\(profile.creditsRequired) credits/run")
            InfoRow(label: "Traffic", value: "\(profile.downloadMegabytes.formattedNoDecimal) MB down + \(profile.uploadIngressMegabytes.formattedNoDecimal) MB up")
            if let dailyHardLimit = profile.dailyHardLimit {
                InfoRow(label: "Used today", value: "\(creditStore.usedToday(for: profile)) / \(dailyHardLimit)")
            }

            runButton

            if creditStore.hasEnoughCredits(for: profile) == false {
                Text("Not enough credits. Add demo credits first.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if creditStore.hasDailyQuota(for: profile) == false {
                Text("Daily limit reached for \(profile.name).")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var runButton: some View {
        if profile.category == .extreme {
            Button {
                run()
            } label: {
                Label(buttonTitle, systemImage: iconName)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning || creditStore.canRun(profile) == false)
        } else {
            Button {
                run()
            } label: {
                Label(buttonTitle, systemImage: iconName)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isRunning || creditStore.canRun(profile) == false)
        }
    }

    private var buttonTitle: String {
        isRunning ? "Testing..." : "Start \(profile.name)"
    }

    private var iconName: String {
        switch profile.category {
        case .free:
            "map"
        case .standard:
            "speedometer"
        case .extreme:
            "bolt.fill"
        }
    }
}

private struct CreditHistoryCard: View {
    var transactions: [CreditTransaction]

    var body: some View {
        CardView(title: "Recent credit activity") {
            if transactions.isEmpty {
                PlaceholderText("No credit activity yet.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(transactions.prefix(6))) { transaction in
                        CreditTransactionRow(transaction: transaction)
                    }
                }
            }
        }
    }
}

private struct CreditTransactionRow: View {
    var transaction: CreditTransaction

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(transaction.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(deltaText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                }

                Text("\(transaction.createdAt.formatted(date: .omitted, time: .shortened)) · \(transaction.note)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var deltaText: String {
        transaction.creditsDelta > 0 ? "+\(transaction.creditsDelta)" : "\(transaction.creditsDelta)"
    }

    private var iconName: String {
        switch transaction.kind {
        case .purchase:
            "plus.circle.fill"
        case .membershipGrant:
            "crown.fill"
        case .speedTestDebit:
            "minus.circle.fill"
        case .speedTestRefund:
            "arrow.uturn.backward.circle.fill"
        }
    }

    private var color: Color {
        switch transaction.kind {
        case .purchase, .membershipGrant, .speedTestRefund:
            .green
        case .speedTestDebit:
            .orange
        }
    }
}

private struct CompactMembershipCard: View {
    @ObservedObject var membershipStore: MembershipStore

    var body: some View {
        CardView(title: "Node mode") {
            InfoRow(label: "Status", value: membershipStore.statusText)
            InfoRow(
                label: "Global nodes",
                value: membershipStore.isPro
                    ? "\(EndpointCatalog.regional.count) nodes unlocked"
                    : "\(EndpointCatalog.freeRegional.count) default nodes, \(EndpointCatalog.premiumRegional.count) premium nodes locked"
            )
        }
    }
}

private struct MembershipNodeUnlockCard: View {
    @ObservedObject var membershipStore: MembershipStore
    @ObservedObject var creditStore: CreditLedgerStore

    var body: some View {
        CardView(title: "Global node mode") {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(membershipStore.isPro ? "Premium global nodes unlocked" : "Enable demo mode to unlock more global nodes")
                        .font(.headline)
                    Text("Default mode keeps core regions. Advanced demo mode opens \(EndpointCatalog.premiumRegional.count) more nodes for cross-border, overseas service, VPN, and routing issues.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    InfoRow(label: "Default nodes", value: "\(EndpointCatalog.freeRegional.count)")
                    InfoRow(label: "Premium nodes", value: "\(EndpointCatalog.premiumRegional.count)")
                }

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Status", value: membershipStore.statusText)
                    Button {
                        unlockMembership()
                    } label: {
                        Label(membershipStore.isPro ? "Extend advanced mode" : "Enable advanced demo mode", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Text(membershipStore.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 260)
            }
        }
    }

    private func unlockMembership() {
        membershipStore.activateProMembership()
        creditStore.addMembershipCredits(membershipStore.plan.monthlyCredits, planName: membershipStore.plan.name)
    }
}

private struct MembershipPlanCard: View {
    @ObservedObject var membershipStore: MembershipStore
    @ObservedObject var creditStore: CreditLedgerStore

    var body: some View {
        CardView(title: "Advanced demo mode") {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Mode", value: membershipStore.plan.name)
                    InfoRow(label: "Status", value: membershipStore.statusText)
                    InfoRow(label: "Demo credits", value: "\(membershipStore.plan.monthlyCredits)/month")
                    InfoRow(label: "Node scope", value: "Unlocks \(EndpointCatalog.premiumRegional.count) premium global nodes")

                    Button {
                        unlockMembership()
                    } label: {
                        Label(membershipStore.isPro ? "Extend demo mode" : "Enable demo mode", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("This is a local open-source demo. If you connect self-hosted nodes or accounts, the server should validate access, grant credits, and limit high-traffic tests.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mode capabilities")
                        .font(.subheadline.weight(.semibold))
                    ForEach(membershipStore.plan.benefits) { benefit in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(benefit.title)
                                .font(.footnote.weight(.semibold))
                            Text(benefit.details)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private func unlockMembership() {
        membershipStore.activateProMembership()
        creditStore.addMembershipCredits(membershipStore.plan.monthlyCredits, planName: membershipStore.plan.name)
    }
}

private struct RegionResultsTab: View {
    var results: [RegionProbeResult]
    @ObservedObject var membershipStore: MembershipStore
    @ObservedObject var creditStore: CreditLedgerStore

    var body: some View {
        MacStyledScrollView {
            VStack(alignment: .leading, spacing: 12) {
                MembershipNodeUnlockCard(membershipStore: membershipStore, creditStore: creditStore)

                HStack(alignment: .top, spacing: 12) {
                    GlobalNodeMapCard(results: results, isPro: membershipStore.isPro)
                        .layoutPriority(1)
                    RegionResultsCard(results: results, isPro: membershipStore.isPro)
                        .frame(width: 320)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

private struct CostProtectionTab: View {
    var policy: CostProtectionPolicy
    @ObservedObject var membershipStore: MembershipStore
    @ObservedObject var creditStore: CreditLedgerStore

    var body: some View {
        MacStyledScrollView {
            VStack(alignment: .leading, spacing: 12) {
                MembershipPlanCard(membershipStore: membershipStore, creditStore: creditStore)

                CardView(title: "Cost protection example") {
                    Text("Bandwidth-heavy speed tests can use prepaid credits. Credits are reserved before a test, and worst-case egress cost is estimated to help you design limits for self-hosted or public services.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    InfoRow(label: "Cost assumption", value: "$\(Int(policy.worstCaseEgressCostPerTerabyteUSD))/TB egress")
                    InfoRow(label: "FX assumption", value: "1 USD = \(policy.usdToRMB.formattedOneDecimal) RMB")
                    InfoRow(label: "Safety threshold", value: "\(Int(policy.minimumGrossMarginRate * 100))%")
                }

                HStack(alignment: .top, spacing: 12) {
                    CreditPackCard(pack: policy.defaultCreditPack)
                    ServerRulesCard()
                }

                MeteredProfilesCard(policy: policy)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

private struct CreditPackCard: View {
    var pack: CreditPack

    var body: some View {
        CardView(title: "Default credit pack") {
            InfoRow(label: "Price", value: pack.priceRMB.formattedRMB)
            InfoRow(label: "Credits", value: "\(pack.credits)")
            InfoRow(label: "Net revenue", value: pack.netRevenueRMB.formattedRMB)
            InfoRow(label: "Net revenue per credit", value: pack.netRevenuePerCreditRMB.formattedRMB)
        }
    }
}

private struct MeteredProfilesCard: View {
    var policy: CostProtectionPolicy

    var body: some View {
        CardView(title: "Speed test credit rules") {
            HStack(alignment: .top, spacing: 12) {
                ForEach(policy.profiles) { profile in
                    MeteredProfileRow(policy: policy, profile: profile)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }
}

private struct MeteredProfileRow: View {
    var policy: CostProtectionPolicy
    var profile: MeteredTestProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(profile.name, systemImage: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                Spacer()
                Text(policy.isProfitProtected(profile) ? "Cost safe" : "Needs tuning")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(policy.isProfitProtected(profile) ? .green : .red)
            }

            Text(profile.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            InfoRow(label: "Credits", value: profile.creditsRequired == 0 ? "Free" : "\(profile.creditsRequired)/run")
            InfoRow(label: "Traffic", value: "\(profile.downloadMegabytes.formattedNoDecimal) MB down + \(profile.uploadIngressMegabytes.formattedNoDecimal) MB upload ingress")
            InfoRow(label: "Cost", value: profile.estimatedEgressCostRMB(perTerabyteUSD: policy.worstCaseEgressCostPerTerabyteUSD, usdToRMB: policy.usdToRMB).formattedRMB)
            if profile.creditsRequired > 0 {
                InfoRow(label: "Margin per run", value: profile.grossMarginRMB(perTerabyteUSD: policy.worstCaseEgressCostPerTerabyteUSD, usdToRMB: policy.usdToRMB, perCreditRMB: policy.netRevenuePerCreditRMB).formattedRMB)
                if let marginRate = profile.grossMarginRate(perTerabyteUSD: policy.worstCaseEgressCostPerTerabyteUSD, usdToRMB: policy.usdToRMB, perCreditRMB: policy.netRevenuePerCreditRMB) {
                    InfoRow(label: "Safety margin", value: marginRate.formattedPercent)
                }
            }
            if let dailyHardLimit = profile.dailyHardLimit {
                InfoRow(label: "Daily cap", value: "\(dailyHardLimit)/user")
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var iconName: String {
        switch profile.category {
        case .free:
            "map"
        case .standard:
            "speedometer"
        case .extreme:
            "bolt.fill"
        }
    }

    private var color: Color {
        switch profile.category {
        case .free:
            .green
        case .standard:
            .blue
        case .extreme:
            .orange
        }
    }
}

private struct ServerRulesCard: View {
    var body: some View {
        CardView(title: "Server integration notes") {
            InfoRow(label: "Reserve credits", value: "Reserve credits before issuing a test URL and refund on failure.")
            InfoRow(label: "Short-lived URL", value: "Speed test URLs should expire within seconds to prevent reuse.")
            InfoRow(label: "Hard caps", value: "Apply daily limits by user, device, IP, and region.")
        }
    }
}

private struct DiagnosisCard: View {
    var summary: DiagnosisSummary

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 6) {
                Label(summary.title, systemImage: iconName)
                    .font(.headline)
                    .foregroundStyle(color)
                Text(summary.details)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var iconName: String {
        switch summary.severity {
        case .good:
            "checkmark.seal.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .problem:
            "xmark.octagon.fill"
        case .unknown:
            "questionmark.circle.fill"
        }
    }

    private var color: Color {
        switch summary.severity {
        case .good:
            .green
        case .warning:
            .orange
        case .problem:
            .red
        case .unknown:
            .secondary
        }
    }
}

private struct DiagnosticProgressCard: View {
    var steps: [DiagnosticProgressStep]

    var body: some View {
        CardView(title: "Diagnostic progress") {
            HStack(spacing: 8) {
                ForEach(steps) { step in
                    DiagnosticProgressRow(step: step)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct DiagnosticProgressRow: View {
    var step: DiagnosticProgressStep

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .foregroundStyle(color)
                .font(.caption.weight(.semibold))

            Text(step.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(statusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .help(step.details)
    }

    private var iconName: String {
        switch step.status {
        case .pending:
            "circle"
        case .running:
            "arrow.triangle.2.circlepath"
        case .completed:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch step.status {
        case .pending:
            .secondary
        case .running:
            .blue
        case .completed:
            .green
        case .failed:
            .orange
        }
    }

    private var statusText: String {
        switch step.status {
        case .pending:
            "Pending"
        case .running:
            "Running"
        case .completed:
            "Done"
        case .failed:
            "Failed"
        }
    }
}

private struct FindingsCard: View {
    var findings: [DiagnosticFinding]

    var body: some View {
        CardView(title: "Findings") {
            if findings.isEmpty {
                PlaceholderText("Run diagnostics to list issues, impact, and severity.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(findings) { finding in
                        FindingRow(finding: finding)
                    }
                }
            }
        }
    }
}

private struct FindingRow: View {
    var finding: DiagnosticFinding

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Label(finding.title, systemImage: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                Spacer()
                Text(severityText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
            }
            Text(finding.details)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Impact: \(finding.impact)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var iconName: String {
        switch finding.severity {
        case .good:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .problem:
            "xmark.octagon.fill"
        case .unknown:
            "questionmark.circle.fill"
        }
    }

    private var color: Color {
        switch finding.severity {
        case .good:
            .green
        case .warning:
            .orange
        case .problem:
            .red
        case .unknown:
            .secondary
        }
    }

    private var severityText: String {
        switch finding.severity {
        case .good:
            "Normal"
        case .warning:
            "Warning"
        case .problem:
            "Issue"
        case .unknown:
            "Unknown"
        }
    }
}

private struct RecommendationsCard: View {
    var actions: [RepairAction]

    var body: some View {
        CardView(title: "Recommendations") {
            if actions.isEmpty {
                PlaceholderText("Run diagnostics to see recommended next steps.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(actions) { action in
                        RecommendationRow(action: action)
                    }
                }
            }
        }
    }
}

private struct RecommendationRow: View {
    var action: RepairAction

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Label(action.title, systemImage: "lightbulb.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Text("Tip")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Text(action.details)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct IPInfoCard: View {
    var info: IPInfo?

    var body: some View {
        CardView(title: "Public IP") {
            if let info {
                InfoRow(label: "IP", value: info.ipAddress)
                InfoRow(label: "Location", value: info.locationDescription.isEmpty ? "Unknown" : info.locationDescription)
                InfoRow(label: "ISP", value: info.isp ?? info.organization ?? "Unknown")
                InfoRow(label: "Timezone", value: info.timezone ?? "Unknown")
                InfoRow(label: "Source", value: info.source)
            } else {
                PlaceholderText("Public IP has not been queried yet.")
            }
        }
    }
}

private struct NetworkPathCard: View {
    var snapshot: NetworkPathSnapshot

    var body: some View {
        CardView(title: "Local network path") {
            InfoRow(label: "Status", value: snapshot.status)
            InfoRow(label: "Interface", value: snapshot.interfaces.isEmpty ? "Unknown" : snapshot.interfaces.joined(separator: ", "))
            InfoRow(label: "IPv4 / IPv6", value: "\(snapshot.supportsIPv4 ? "Yes" : "No") / \(snapshot.supportsIPv6 ? "Yes" : "No")")
            InfoRow(label: "DNS", value: snapshot.supportsDNS ? "Yes" : "No")
            InfoRow(label: "Low data / constrained", value: snapshot.isConstrained ? "Yes" : "No")
            InfoRow(label: "Expensive network", value: snapshot.isExpensive ? "Yes" : "No")
            InfoRow(label: "VPN clues", value: snapshot.likelyUsesVPN ? "Detected utun/tun/tap/ppp interfaces" : "Not detected")
        }
    }
}

private struct SpeedResultCard: View {
    var title = "Baseline speed test"
    var result: SpeedTestResult?

    var body: some View {
        CardView(title: title) {
            if let result {
                InfoRow(label: "Download", value: result.downloadMbps?.formattedMbps ?? "Failed")
                InfoRow(label: "Upload", value: result.uploadMbps?.formattedMbps ?? "Failed")
                InfoRow(label: "Latency", value: result.latencyMilliseconds?.formattedMilliseconds ?? "Unknown")
                InfoRow(label: "Jitter", value: result.jitterMilliseconds?.formattedMilliseconds ?? "Unknown")
                InfoRow(label: "Endpoint", value: result.endpointName)
                if let error = result.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } else {
                PlaceholderText("No speed test has been run yet.")
            }
        }
    }
}

private struct GlobalNodeMapCard: View {
    var results: [RegionProbeResult]
    var isPro: Bool
    @Environment(\.screenshotPreview) private var screenshotPreview
    @State private var hoveredNodeID: String?
    @State private var mapPosition: MapCameraPosition = .region(Self.worldRegion)

    private static let worldRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 12, longitude: 15),
        span: MKCoordinateSpan(latitudeDelta: 155, longitudeDelta: 360)
    )

    private var displayResults: [RegionProbeResult] {
        mergedRegionResults(results, isPro: isPro)
    }

    private var hoveredResult: RegionProbeResult? {
        displayResults.first { $0.id == hoveredNodeID }
    }

    var body: some View {
        CardView(title: "Global node map") {
            VStack(alignment: .leading, spacing: 10) {
                Text(isPro ? "Advanced mode unlocked all global nodes. Colors reflect latency: green fast, orange moderate, red slow, gray failed." : "Gray sparkle nodes are premium demo nodes and will be probed after advanced mode is enabled.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if screenshotPreview {
                        StaticScreenshotMapView(results: displayResults, isPro: isPro)
                    } else {
                        Map(position: $mapPosition, interactionModes: [.pan, .zoom]) {
                            ForEach(displayResults) { result in
                                Annotation(result.displayName, coordinate: coordinate(for: result), anchor: .center) {
                                    MapNodeView(result: result, isLocked: isLocked(result))
                                        .onHover { isHovering in
                                            hoveredNodeID = isHovering ? result.id : nil
                                        }
                                        .help(nodeTooltip(for: result))
                                }
                            }
                        }
                        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
                        .mapControls {
                            MapCompass()
                            MapScaleView()
                        }
                    }

                    if let hoveredResult, screenshotPreview == false {
                        NodeTooltipCard(result: hoveredResult)
                            .frame(width: 240)
                            .padding(12)
                            .transition(.opacity)
                    }
                }
                .frame(minHeight: 410)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], alignment: .leading, spacing: 8) {
                    Button("World") {
                        withAnimation {
                            mapPosition = .region(Self.worldRegion)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    ForEach(displayResults) { result in
                        Button(result.displayName) {
                            withAnimation {
                                mapPosition = .region(focusedRegion(for: result))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(nodeColor(for: result))
                    }
                }

                HStack(spacing: 14) {
                    MapLegendItem(color: .green, label: "Fast < 200 ms")
                    MapLegendItem(color: .orange, label: "Moderate < 700 ms")
                    MapLegendItem(color: .red, label: "Slow >= 700 ms")
                    MapLegendItem(color: .gray, label: isPro ? "Failed" : "Failed / premium")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func coordinate(for result: RegionProbeResult) -> CLLocationCoordinate2D {
        switch result.regionCode.uppercased() {
        case "US-W", "US-WEST":
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        case "US-E", "US-EAST", "US":
            CLLocationCoordinate2D(latitude: 39.0438, longitude: -77.4874)
        case "US-C":
            CLLocationCoordinate2D(latitude: 39.9612, longitude: -82.9988)
        case "CA":
            CLLocationCoordinate2D(latitude: 45.5019, longitude: -73.5674)
        case "BR":
            CLLocationCoordinate2D(latitude: -23.5558, longitude: -46.6396)
        case "EU", "EUROPE":
            CLLocationCoordinate2D(latitude: 53.3498, longitude: -6.2603)
        case "UK":
            CLLocationCoordinate2D(latitude: 51.5072, longitude: -0.1276)
        case "DE":
            CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821)
        case "FR":
            CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        case "SE":
            CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        case "IT":
            CLLocationCoordinate2D(latitude: 45.4642, longitude: 9.1900)
        case "IN":
            CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)
        case "JP", "JAPAN":
            CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
        case "KR":
            CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        case "HK":
            CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694)
        case "ID":
            CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        case "SG", "SINGAPORE":
            CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198)
        case "AU", "AUSTRALIA":
            CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
        case "CN", "CHINA":
            CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        case "AE":
            CLLocationCoordinate2D(latitude: 25.2048, longitude: 55.2708)
        case "ZA":
            CLLocationCoordinate2D(latitude: -33.9249, longitude: 18.4241)
        default:
            coordinateByDisplayName(result.displayName)
        }
    }

    private func coordinateByDisplayName(_ name: String) -> CLLocationCoordinate2D {
        let normalizedName = name.lowercased()
        if normalizedName.contains("west") {
            return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        }
        if normalizedName.contains("east") {
            return CLLocationCoordinate2D(latitude: 39.0438, longitude: -77.4874)
        }
        if normalizedName.contains("europe") {
            return CLLocationCoordinate2D(latitude: 53.3498, longitude: -6.2603)
        }
        if normalizedName.contains("japan") {
            return CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
        }
        if normalizedName.contains("singapore") {
            return CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198)
        }
        if normalizedName.contains("australia") {
            return CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
        }
        if normalizedName.contains("china") {
            return CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        }
        return CLLocationCoordinate2D(latitude: 20, longitude: 0)
    }

    private func focusedRegion(for result: RegionProbeResult) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate(for: result),
            span: MKCoordinateSpan(latitudeDelta: 28, longitudeDelta: 45)
        )
    }

    private func nodeColor(for result: RegionProbeResult) -> Color {
        if isLocked(result) {
            return .gray
        }
        guard result.isReachable, let latency = result.latencyMilliseconds else {
            return .gray
        }
        if latency < 200 {
            return .green
        }
        if latency < 700 {
            return .orange
        }
        return .red
    }

    private func nodeTooltip(for result: RegionProbeResult) -> String {
        if isLocked(result) {
            return [
                result.displayName,
                "Status: premium demo node",
                "Note: probed after advanced mode is enabled",
                "Endpoint: \(result.endpointHost)"
            ].joined(separator: "\n")
        }

        return [
            result.displayName,
            "Latency: \(result.latencyMilliseconds?.formattedMilliseconds ?? "Failed")",
            "Download: \(result.downloadMbps?.formattedMbps ?? "Latency only / failed")",
            "Endpoint: \(result.endpointHost)"
        ].joined(separator: "\n")
    }

    private func isLocked(_ result: RegionProbeResult) -> Bool {
        result.requiresMembership && isPro == false
    }
}

private struct StaticScreenshotMapView: View {
    var results: [RegionProbeResult]
    var isPro: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.78, green: 0.90, blue: 0.98), Color(red: 0.90, green: 0.96, blue: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.67, green: 0.84, blue: 0.95).opacity(0.55))
                .frame(width: 220, height: 130)
                .offset(x: -180, y: -40)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.67, green: 0.84, blue: 0.95).opacity(0.55))
                .frame(width: 130, height: 110)
                .offset(x: -60, y: -70)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.67, green: 0.84, blue: 0.95).opacity(0.55))
                .frame(width: 150, height: 130)
                .offset(x: 70, y: -30)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.67, green: 0.84, blue: 0.95).opacity(0.55))
                .frame(width: 110, height: 90)
                .offset(x: 250, y: 10)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.67, green: 0.84, blue: 0.95).opacity(0.55))
                .frame(width: 90, height: 70)
                .offset(x: -120, y: 110)

            ForEach(results) { result in
                let point = projectedPoint(for: result)
                MapNodeView(result: result, isLocked: result.requiresMembership && isPro == false)
                    .position(point)
            }
        }
    }

    private func projectedPoint(for result: RegionProbeResult) -> CGPoint {
        let latitude = coordinateLatitude(for: result)
        let longitude = coordinateLongitude(for: result)
        let x = (longitude + 180) / 360 * 920 + 30
        let y = (90 - latitude) / 180 * 380 + 20
        return CGPoint(x: x, y: y)
    }

    private func coordinateLatitude(for result: RegionProbeResult) -> Double {
        switch result.regionCode.uppercased() {
        case "US-W", "US-WEST": 37.7749
        case "US-E", "US-EAST", "US": 39.0438
        case "CA": 45.5019
        case "BR": -23.5558
        case "EU", "EUROPE", "UK", "DE", "FR", "SE", "IT": 50.0
        case "IN": 19.0760
        case "JP", "JAPAN": 35.6762
        case "KR": 37.5665
        case "HK": 22.3193
        case "SG", "SINGAPORE": 1.3521
        case "AU", "AUSTRALIA": -33.8688
        case "CN", "CHINA": 31.2304
        default: 20.0
        }
    }

    private func coordinateLongitude(for result: RegionProbeResult) -> Double {
        switch result.regionCode.uppercased() {
        case "US-W", "US-WEST": -122.4194
        case "US-E", "US-EAST", "US": -77.4874
        case "CA": -73.5674
        case "BR": -46.6396
        case "EU", "EUROPE": -6.2603
        case "UK": -0.1276
        case "DE": 8.6821
        case "FR": 2.3522
        case "IN": 72.8777
        case "JP", "JAPAN": 139.6503
        case "KR": 126.9780
        case "HK": 114.1694
        case "SG", "SINGAPORE": 103.8198
        case "AU", "AUSTRALIA": 151.2093
        case "CN", "CHINA": 121.4737
        default: 0.0
        }
    }
}

private struct MapNodeView: View {
    var result: RegionProbeResult
    var isLocked: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(nodeColor.opacity(0.22))
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(nodeColor)
                    .frame(width: 14, height: 14)
                    .shadow(color: nodeColor.opacity(0.5), radius: 6)
                if isLocked {
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 2)
                    .frame(width: 14, height: 14)
            }
            Text(result.displayName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.regularMaterial)
                .clipShape(Capsule())
        }
    }

    private var nodeColor: Color {
        if isLocked {
            return .gray
        }
        guard result.isReachable, let latency = result.latencyMilliseconds else {
            return .gray
        }
        if latency < 200 {
            return .green
        }
        if latency < 700 {
            return .orange
        }
        return .red
    }
}

private struct NodeTooltipCard: View {
    var result: RegionProbeResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.displayName)
                .font(.headline)
            InfoRow(label: "Status", value: result.isReachable ? "Reachable" : "Failed")
            InfoRow(label: "Latency", value: result.latencyMilliseconds?.formattedMilliseconds ?? "Failed")
            InfoRow(label: "Download", value: result.downloadMbps?.formattedMbps ?? "Latency only / failed")
            InfoRow(label: "Endpoint", value: result.endpointHost)
            if let errorMessage = result.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(radius: 12)
    }
}

private struct MapLegendItem: View {
    var color: Color
    var label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

private struct RegionResultsCard: View {
    var results: [RegionProbeResult]
    var isPro: Bool

    private var displayResults: [RegionProbeResult] {
        mergedRegionResults(results, isPro: isPro)
    }

    var body: some View {
        CardView(title: "Global regional nodes") {
            if displayResults.isEmpty {
                PlaceholderText("No regional nodes configured yet.")
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 10) {
                    ForEach(displayResults) { result in
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(result.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    if result.requiresMembership {
                                        Image(systemName: "crown.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Text(result.requiresMembership && isPro == false ? "Premium node" : result.endpointHost)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(result.requiresMembership && isPro == false ? "Locked" : result.latencyMilliseconds?.formattedMilliseconds ?? "Failed")
                                    .font(.headline)
                                Text(result.requiresMembership && isPro == false ? "Premium" : result.downloadMbps?.formattedMbps ?? "Latency only")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }
}

private func mergedRegionResults(_ results: [RegionProbeResult], isPro: Bool) -> [RegionProbeResult] {
    let actualByCode = Dictionary(uniqueKeysWithValues: results.map { ($0.regionCode, $0) })

    return EndpointCatalog.regional.map { endpoint in
        let regionCode = endpoint.regionCode ?? endpoint.id
        if let actual = actualByCode[regionCode] {
            return actual
        }

        return RegionProbeResult(
            regionCode: regionCode,
            displayName: endpoint.name,
            endpointHost: endpoint.url.host() ?? endpoint.url.absoluteString,
            latencyMilliseconds: nil,
            downloadMbps: nil,
            isReachable: false,
            errorMessage: endpoint.requiresMembership && isPro == false ? "Premium demo node. Enable advanced mode to unlock." : "Not probed yet",
            requiresMembership: endpoint.requiresMembership
        )
    }
}

private struct MacStyledScrollView<Content: View>: View {
    @State private var viewportHeight: CGFloat = 1
    @State private var contentHeight: CGFloat = 1
    @State private var scrollOffset: CGFloat = 0

    private let coordinateSpaceName = "mac-styled-scroll-view"
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .background {
                        GeometryReader { contentGeometry in
                            Color.clear
                                .preference(
                                    key: ScrollContentHeightPreferenceKey.self,
                                    value: contentGeometry.size.height
                                )
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: -contentGeometry.frame(in: .named(coordinateSpaceName)).minY
                                )
                        }
                    }
            }
            .coordinateSpace(name: coordinateSpaceName)
            .onAppear {
                viewportHeight = geometry.size.height
            }
            .onChange(of: geometry.size.height) { _, height in
                viewportHeight = height
            }
            .onPreferenceChange(ScrollContentHeightPreferenceKey.self) { height in
                contentHeight = height
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                scrollOffset = offset
            }
            .overlay(alignment: .trailing) {
                MacScrollIndicator(
                    viewportHeight: viewportHeight,
                    contentHeight: contentHeight,
                    scrollOffset: scrollOffset
                )
            }
        }
    }
}

private struct MacScrollIndicator: View {
    var viewportHeight: CGFloat
    var contentHeight: CGFloat
    var scrollOffset: CGFloat

    var body: some View {
        if contentHeight > viewportHeight + 1 {
            Capsule()
                .fill(.secondary.opacity(0.28))
                .frame(width: 4, height: thumbHeight)
                .offset(y: thumbOffset)
                .frame(width: 10, height: viewportHeight - 16, alignment: .top)
                .padding(.vertical, 8)
                .padding(.trailing, 4)
                .allowsHitTesting(false)
        }
    }

    private var trackHeight: CGFloat {
        max(viewportHeight - 16, 0)
    }

    private var thumbHeight: CGFloat {
        max(36, trackHeight * viewportHeight / max(contentHeight, 1))
    }

    private var thumbOffset: CGFloat {
        let maxContentOffset = max(contentHeight - viewportHeight, 1)
        let progress = min(max(scrollOffset / maxContentOffset, 0), 1)
        return progress * max(trackHeight - thumbHeight, 0)
    }
}

private struct ScrollContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 1

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct InfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

private struct PlaceholderText: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CardView<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private extension Double {
    var formattedNoDecimal: String {
        String(format: "%.0f", self)
    }

    var formattedOneDecimal: String {
        String(format: "%.1f", self)
    }

}
