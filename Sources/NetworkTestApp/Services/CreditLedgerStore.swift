import Foundation

@MainActor
final class CreditLedgerStore: ObservableObject {
    @Published private(set) var balance: Int
    @Published private(set) var transactions: [CreditTransaction]
    @Published var message: String

    private let userDefaults: UserDefaults
    private let balanceKey = "credit-ledger.balance"
    private let transactionsKey = "credit-ledger.transactions"

    init(seedCredits: Int = 6, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if userDefaults.object(forKey: balanceKey) == nil {
            self.balance = seedCredits
            self.transactions = [
                CreditTransaction(
                    id: UUID(),
                    kind: .purchase,
                    profileID: nil,
                    title: "体验额度",
                    creditsDelta: seedCredits,
                    createdAt: .now,
                    note: "本地开源演示预置，用来体验标准/极限测速额度流程。"
                )
            ]
            self.message = "已发放 \(seedCredits) 点体验额度"
            persist()
        } else {
            self.balance = userDefaults.integer(forKey: balanceKey)
            self.transactions = Self.decodeTransactions(from: userDefaults.data(forKey: transactionsKey))
            self.message = "额度账本已加载"
        }
    }

    func canRun(_ profile: MeteredTestProfile) -> Bool {
        hasEnoughCredits(for: profile) && hasDailyQuota(for: profile)
    }

    func hasEnoughCredits(for profile: MeteredTestProfile) -> Bool {
        balance >= profile.creditsRequired
    }

    func hasDailyQuota(for profile: MeteredTestProfile) -> Bool {
        guard let dailyHardLimit = profile.dailyHardLimit else { return true }
        return usedToday(for: profile) < dailyHardLimit
    }

    func usedToday(for profile: MeteredTestProfile) -> Int {
        transactions.filter { transaction in
            transaction.kind == .speedTestDebit
                && transaction.profileID == profile.id
                && Calendar.current.isDateInToday(transaction.createdAt)
        }.count
    }

    @discardableResult
    func consumeCredits(for profile: MeteredTestProfile) -> Bool {
        guard hasDailyQuota(for: profile) else {
            message = "\(profile.name) 今日次数已用完"
            return false
        }
        guard hasEnoughCredits(for: profile) else {
            message = "额度不足，无法运行 \(profile.name)"
            return false
        }

        balance -= profile.creditsRequired
        appendTransaction(
            kind: .speedTestDebit,
            profile: profile,
            title: profile.name,
            creditsDelta: -profile.creditsRequired,
            note: "测速开始前预扣额度。"
        )
        message = "已预扣 \(profile.creditsRequired) 点额度，开始 \(profile.name)"
        return true
    }

    func refundCredits(for profile: MeteredTestProfile, reason: String) {
        guard profile.creditsRequired > 0 else { return }

        balance += profile.creditsRequired
        appendTransaction(
            kind: .speedTestRefund,
            profile: profile,
            title: "\(profile.name) 退回额度",
            creditsDelta: profile.creditsRequired,
            note: reason
        )
        message = "\(profile.name) 失败，已退回 \(profile.creditsRequired) 点额度"
    }

    func addCredits(from pack: CreditPack) {
        balance += pack.credits
        appendTransaction(
            kind: .purchase,
            profile: nil,
            title: pack.name,
            creditsDelta: pack.credits,
            note: "本地模拟补充。接入账号系统后应由服务端账本入账。"
        )
        message = "已补充 \(pack.credits) 点演示额度"
    }

    func addMembershipCredits(_ credits: Int, planName: String) {
        balance += credits
        appendTransaction(
            kind: .membershipGrant,
            profile: nil,
            title: "\(planName) 额度",
            creditsDelta: credits,
            note: "本地模拟高级模式额度发放。接入账号系统后应由服务端控制。"
        )
        message = "\(planName) 已发放 \(credits) 点额度"
    }

    private func appendTransaction(
        kind: CreditTransactionKind,
        profile: MeteredTestProfile?,
        title: String,
        creditsDelta: Int,
        note: String
    ) {
        transactions.insert(
            CreditTransaction(
                id: UUID(),
                kind: kind,
                profileID: profile?.id,
                title: title,
                creditsDelta: creditsDelta,
                createdAt: .now,
                note: note
            ),
            at: 0
        )
        transactions = Array(transactions.prefix(30))
        persist()
    }

    private func persist() {
        userDefaults.set(balance, forKey: balanceKey)
        if let data = try? JSONEncoder().encode(transactions) {
            userDefaults.set(data, forKey: transactionsKey)
        }
    }

    private static func decodeTransactions(from data: Data?) -> [CreditTransaction] {
        guard let data,
              let transactions = try? JSONDecoder().decode([CreditTransaction].self, from: data) else {
            return []
        }
        return transactions
    }
}
