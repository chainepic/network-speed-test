import SwiftUI
import MapKit

struct DashboardView: View {
    @StateObject private var viewModel = DiagnosticsViewModel()
    @StateObject private var creditStore = CreditLedgerStore()
    @StateObject private var membershipStore = MembershipStore()
    private let costPolicy = CostProtectionPolicy.productionSafe

    var body: some View {
        TabView {
            DiagnosisOverviewTab(viewModel: viewModel, membershipStore: membershipStore)
                .tabItem {
                    Label("总览", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }

            SpeedDiagnosticsTab(viewModel: viewModel, creditStore: creditStore, policy: costPolicy)
                .tabItem {
                    Label("测速", systemImage: "speedometer")
                }

            RegionResultsTab(results: viewModel.regionResults, membershipStore: membershipStore, creditStore: creditStore)
                .tabItem {
                    Label("全球节点", systemImage: "map")
                }

            CostProtectionTab(policy: costPolicy, membershipStore: membershipStore, creditStore: creditStore)
                .tabItem {
                    Label("开源实验", systemImage: "shippingbox")
                }
        }
        .frame(minWidth: 920, minHeight: 600)
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
                            Label(viewModel.isRunning ? "诊断中..." : "开始网络诊断", systemImage: "network")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(viewModel.isRunning)

                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        Text(membershipStore.isPro ? "本次会探测全部 \(EndpointCatalog.regional.count) 个全球节点" : "默认探测 \(EndpointCatalog.freeRegional.count) 个核心节点")
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

                CardView(title: "开源演示说明") {
                    Text("当前仓库是本地优先的开源示例：额度和流水保存在本机，用来演示高流量测速的成本保护思路。接入自建节点时，额度校验、退款、每日上限和测速 URL 签发应由服务端执行。")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    InfoRow(label: "预扣额度", value: "点击测速前先扣额度，失败后自动退回。")
                    InfoRow(label: "短期 URL", value: "接入服务端时建议签发一次性测速 URL。")
                    InfoRow(label: "防刷限额", value: "现在已有本地每日次数检查，生产需要账号/设备/IP 多维限流。")
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
                creditStore.refundCredits(for: profile, reason: "测速请求失败，自动退回预扣额度。")
            }
        }
    }
}

private struct SpeedEndpointInfoCard: View {
    var body: some View {
        CardView(title: "当前测速节点说明") {
            Text("标准/极限测速目前都使用第三方公共测速端点，不是我们自建机房。下载和上传优先走 Cloudflare Speed Test 的全球边缘节点，实际落到哪个城市由 Cloudflare Anycast 和你的网络路由决定。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            InfoRow(label: "下载", value: "speed.cloudflare.com/__down，按测速档位生成 100 MB 或 250 MB 下载")
            InfoRow(label: "上传", value: "speed.cloudflare.com/__up，按测速档位上传 30 MB 或 50 MB")
            InfoRow(label: "fallback", value: "上传失败时保留 httpbin.org/post 作为备用公共端点")
            InfoRow(label: "全球节点", value: "全球节点页探测的是区域端点：Google/Baidu + AWS DynamoDB 各区域入口")
        }
    }
}

private struct CreditWalletCard: View {
    @ObservedObject var creditStore: CreditLedgerStore
    var pack: CreditPack

    var body: some View {
        CardView(title: "测试额度") {
            InfoRow(label: "当前余额", value: "\(creditStore.balance) 点额度")
            InfoRow(label: "演示补充包", value: "\(pack.priceRMB.formattedRMB) / \(pack.credits) 点额度")

            Button {
                creditStore.addCredits(from: pack)
            } label: {
                Label("补充演示额度", systemImage: "plus.circle.fill")
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

            InfoRow(label: "消耗", value: "\(profile.creditsRequired) 点额度/次")
            InfoRow(label: "流量", value: "\(profile.downloadMegabytes.formattedNoDecimal) MB 下载 + \(profile.uploadIngressMegabytes.formattedNoDecimal) MB 上传")
            if let dailyHardLimit = profile.dailyHardLimit {
                InfoRow(label: "今日次数", value: "\(creditStore.usedToday(for: profile)) / \(dailyHardLimit)")
            }

            runButton

            if creditStore.hasEnoughCredits(for: profile) == false {
                Text("额度不足，请先补充演示额度。")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if creditStore.hasDailyQuota(for: profile) == false {
                Text("今日 \(profile.name) 次数已用完。")
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
        isRunning ? "测速中..." : "开始\(profile.name)"
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
        CardView(title: "最近额度流水") {
            if transactions.isEmpty {
                PlaceholderText("还没有额度流水。")
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
        CardView(title: "节点模式") {
            InfoRow(label: "当前状态", value: membershipStore.statusText)
            InfoRow(
                label: "全球节点",
                value: membershipStore.isPro
                    ? "\(EndpointCatalog.regional.count) 个节点已解锁"
                    : "\(EndpointCatalog.freeRegional.count) 个默认节点，\(EndpointCatalog.premiumRegional.count) 个高级节点待解锁"
            )
        }
    }
}

private struct MembershipNodeUnlockCard: View {
    @ObservedObject var membershipStore: MembershipStore
    @ObservedObject var creditStore: CreditLedgerStore

    var body: some View {
        CardView(title: "全球节点模式") {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(membershipStore.isPro ? "高级全球节点已解锁" : "启用演示模式后解锁更多全球节点")
                        .font(.headline)
                    Text("默认模式保留核心区域，高级演示模式会额外开放 \(EndpointCatalog.premiumRegional.count) 个节点，用于定位跨境、海外服务、VPN 和区域路由问题。")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    InfoRow(label: "默认节点", value: "\(EndpointCatalog.freeRegional.count) 个")
                    InfoRow(label: "高级节点", value: "\(EndpointCatalog.premiumRegional.count) 个")
                }

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "状态", value: membershipStore.statusText)
                    Button {
                        unlockMembership()
                    } label: {
                        Label(membershipStore.isPro ? "延长高级模式" : "启用高级演示模式", systemImage: "sparkles")
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
        CardView(title: "高级实验模式") {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "模式", value: membershipStore.plan.name)
                    InfoRow(label: "状态", value: membershipStore.statusText)
                    InfoRow(label: "演示额度", value: "\(membershipStore.plan.monthlyCredits) 点/月")
                    InfoRow(label: "节点范围", value: "解锁 \(EndpointCatalog.premiumRegional.count) 个高级全球节点")

                    Button {
                        unlockMembership()
                    } label: {
                        Label(membershipStore.isPro ? "延长演示模式" : "启用演示模式", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("当前是本地开源演示。若你接入自建节点或账号系统，应由服务端校验权限、发放额度并限制高流量测速。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("模式能力")
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

                CardView(title: "成本保护示例") {
                    Text("会消耗服务器带宽的测速可以使用预付额度。测速前先扣额度，并按最坏公网出站成本估算风险，适合给自建节点或公开服务做限额参考。")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    InfoRow(label: "成本假设", value: "$\(Int(policy.worstCaseEgressCostPerTerabyteUSD))/TB 出站流量")
                    InfoRow(label: "汇率假设", value: "1 USD = \(policy.usdToRMB.formattedOneDecimal) RMB")
                    InfoRow(label: "安全阈值", value: "\(Int(policy.minimumGrossMarginRate * 100))%")
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
        CardView(title: "默认额度包") {
            InfoRow(label: "价格", value: pack.priceRMB.formattedRMB)
            InfoRow(label: "额度", value: "\(pack.credits) 点")
            InfoRow(label: "平台后收入", value: pack.netRevenueRMB.formattedRMB)
            InfoRow(label: "每点净收入", value: pack.netRevenuePerCreditRMB.formattedRMB)
        }
    }
}

private struct MeteredProfilesCard: View {
    var policy: CostProtectionPolicy

    var body: some View {
        CardView(title: "测速额度规则") {
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
                Text(policy.isProfitProtected(profile) ? "成本安全" : "需要调整")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(policy.isProfitProtected(profile) ? .green : .red)
            }

            Text(profile.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            InfoRow(label: "额度", value: profile.creditsRequired == 0 ? "免费" : "\(profile.creditsRequired) 点/次")
            InfoRow(label: "流量", value: "\(profile.downloadMegabytes.formattedNoDecimal) MB 下载 + \(profile.uploadIngressMegabytes.formattedNoDecimal) MB 上传入口")
            InfoRow(label: "成本", value: profile.estimatedEgressCostRMB(perTerabyteUSD: policy.worstCaseEgressCostPerTerabyteUSD, usdToRMB: policy.usdToRMB).formattedRMB)
            if profile.creditsRequired > 0 {
                InfoRow(label: "单次余量", value: profile.grossMarginRMB(perTerabyteUSD: policy.worstCaseEgressCostPerTerabyteUSD, usdToRMB: policy.usdToRMB, perCreditRMB: policy.netRevenuePerCreditRMB).formattedRMB)
                if let marginRate = profile.grossMarginRate(perTerabyteUSD: policy.worstCaseEgressCostPerTerabyteUSD, usdToRMB: policy.usdToRMB, perCreditRMB: policy.netRevenuePerCreditRMB) {
                    InfoRow(label: "安全余量", value: marginRate.formattedPercent)
                }
            }
            if let dailyHardLimit = profile.dailyHardLimit {
                InfoRow(label: "每日上限", value: "\(dailyHardLimit) 次/用户")
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
        CardView(title: "接入服务端建议") {
            InfoRow(label: "预扣额度", value: "发测速 URL 前扣额度，失败再按规则退回。")
            InfoRow(label: "短期 URL", value: "测速 URL 只在几十秒内有效，防止被复制滥用。")
            InfoRow(label: "硬上限", value: "按用户、设备、IP、地区做每日限额。")
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
        CardView(title: "诊断进度") {
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
            "等待"
        case .running:
            "进行中"
        case .completed:
            "完成"
        case .failed:
            "失败"
        }
    }
}

private struct FindingsCard: View {
    var findings: [DiagnosticFinding]

    var body: some View {
        CardView(title: "诊断发现") {
            if findings.isEmpty {
                PlaceholderText("运行诊断后，会列出具体问题、影响范围和严重程度。")
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
            Text("影响：\(finding.impact)")
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
            "正常"
        case .warning:
            "注意"
        case .problem:
            "问题"
        case .unknown:
            "待确认"
        }
    }
}

private struct RecommendationsCard: View {
    var actions: [RepairAction]

    var body: some View {
        CardView(title: "处理建议") {
            if actions.isEmpty {
                PlaceholderText("运行诊断后，会给出下一步处理建议。")
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
                Text("建议")
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
        CardView(title: "公网 IP") {
            if let info {
                InfoRow(label: "IP", value: info.ipAddress)
                InfoRow(label: "位置", value: info.locationDescription.isEmpty ? "未知" : info.locationDescription)
                InfoRow(label: "运营商", value: info.isp ?? info.organization ?? "未知")
                InfoRow(label: "时区", value: info.timezone ?? "未知")
                InfoRow(label: "来源", value: info.source)
            } else {
                PlaceholderText("尚未查询公网 IP")
            }
        }
    }
}

private struct NetworkPathCard: View {
    var snapshot: NetworkPathSnapshot

    var body: some View {
        CardView(title: "本机网络路径") {
            InfoRow(label: "状态", value: snapshot.status)
            InfoRow(label: "接口", value: snapshot.interfaces.isEmpty ? "未知" : snapshot.interfaces.joined(separator: ", "))
            InfoRow(label: "IPv4 / IPv6", value: "\(snapshot.supportsIPv4 ? "支持" : "不支持") / \(snapshot.supportsIPv6 ? "支持" : "不支持")")
            InfoRow(label: "DNS", value: snapshot.supportsDNS ? "支持" : "不支持")
            InfoRow(label: "低数据/受限", value: snapshot.isConstrained ? "是" : "否")
            InfoRow(label: "昂贵网络", value: snapshot.isExpensive ? "是" : "否")
            InfoRow(label: "VPN 线索", value: snapshot.likelyUsesVPN ? "检测到 utun/tun/tap/ppp 接口" : "未检测到")
        }
    }
}

private struct SpeedResultCard: View {
    var title = "基础测速"
    var result: SpeedTestResult?

    var body: some View {
        CardView(title: title) {
            if let result {
                InfoRow(label: "下载", value: result.downloadMbps?.formattedMbps ?? "失败")
                InfoRow(label: "上传", value: result.uploadMbps?.formattedMbps ?? "失败")
                InfoRow(label: "延迟", value: result.latencyMilliseconds?.formattedMilliseconds ?? "未知")
                InfoRow(label: "抖动", value: result.jitterMilliseconds?.formattedMilliseconds ?? "未知")
                InfoRow(label: "端点", value: result.endpointName)
                if let error = result.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } else {
                PlaceholderText("尚未运行测速")
            }
        }
    }
}

private struct GlobalNodeMapCard: View {
    var results: [RegionProbeResult]
    var isPro: Bool
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
        CardView(title: "全球节点地图") {
            VStack(alignment: .leading, spacing: 10) {
                Text(isPro ? "高级模式已解锁全部全球节点。颜色按延迟判断：绿色快，橙色一般，红色慢，灰色失败。" : "灰色星标节点为高级演示节点，启用后会参与探测。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
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

                    if let hoveredResult {
                        NodeTooltipCard(result: hoveredResult)
                            .frame(width: 240)
                            .padding(12)
                            .transition(.opacity)
                    }
                }
                .frame(minHeight: 410)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], alignment: .leading, spacing: 8) {
                    Button("全图") {
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
                    MapLegendItem(color: .green, label: "快 < 200 ms")
                    MapLegendItem(color: .orange, label: "一般 < 700 ms")
                    MapLegendItem(color: .red, label: "慢 >= 700 ms")
                    MapLegendItem(color: .gray, label: isPro ? "失败" : "失败/高级节点")
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
                "状态：高级演示节点",
                "说明：启用后参与探测",
                "端点：\(result.endpointHost)"
            ].joined(separator: "\n")
        }

        return [
            result.displayName,
            "延迟：\(result.latencyMilliseconds?.formattedMilliseconds ?? "失败")",
            "下载：\(result.downloadMbps?.formattedMbps ?? "仅延迟/失败")",
            "端点：\(result.endpointHost)"
        ].joined(separator: "\n")
    }

    private func isLocked(_ result: RegionProbeResult) -> Bool {
        result.requiresMembership && isPro == false
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
            InfoRow(label: "状态", value: result.isReachable ? "可达" : "失败")
            InfoRow(label: "延迟", value: result.latencyMilliseconds?.formattedMilliseconds ?? "失败")
            InfoRow(label: "下载", value: result.downloadMbps?.formattedMbps ?? "仅延迟/失败")
            InfoRow(label: "端点", value: result.endpointHost)
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
        CardView(title: "全球区域节点") {
            if displayResults.isEmpty {
                PlaceholderText("尚未配置区域节点")
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
                                Text(result.requiresMembership && isPro == false ? "高级节点" : result.endpointHost)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(result.requiresMembership && isPro == false ? "待解锁" : result.latencyMilliseconds?.formattedMilliseconds ?? "失败")
                                    .font(.headline)
                                Text(result.requiresMembership && isPro == false ? "高级" : result.downloadMbps?.formattedMbps ?? "仅延迟")
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
            errorMessage: endpoint.requiresMembership && isPro == false ? "高级演示节点，启用后解锁。" : "尚未探测",
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
