import Foundation

@MainActor
final class MembershipStore: ObservableObject {
    @Published private(set) var expiresAt: Date?
    @Published var message: String

    let plan: MembershipPlan

    private let userDefaults: UserDefaults
    private let expiresAtKey = "membership.pro.expiresAt"

    init(plan: MembershipPlan = .pro, userDefaults: UserDefaults = .standard) {
        self.plan = plan
        self.userDefaults = userDefaults
        let timestamp = userDefaults.double(forKey: expiresAtKey)
        let storedExpiresAt = timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        self.expiresAt = storedExpiresAt
        self.message = storedExpiresAt.map { "高级模式有效期至 \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "当前为默认模式"
    }

    var isPro: Bool {
        guard let expiresAt else { return false }
        return expiresAt > .now
    }

    var statusText: String {
        guard isPro, let expiresAt else { return "默认模式" }
        return "\(plan.name) · 有效期至 \(expiresAt.formatted(date: .abbreviated, time: .omitted))"
    }

    var unlockedNodeCount: Int {
        EndpointCatalog.regionalEndpoints(includePremium: isPro).count
    }

    var lockedPremiumNodeCount: Int {
        isPro ? 0 : EndpointCatalog.premiumRegional.count
    }

    @discardableResult
    func activateProMembership(days: Int = 30) -> Bool {
        let baseDate = isPro ? (expiresAt ?? .now) : .now
        let newExpiry = Calendar.current.date(byAdding: .day, value: days, to: baseDate) ?? .now.addingTimeInterval(Double(days) * 86_400)
        expiresAt = newExpiry
        userDefaults.set(newExpiry.timeIntervalSince1970, forKey: expiresAtKey)
        message = "已启用 \(plan.name)，高级全球节点已开启"
        return true
    }
}
