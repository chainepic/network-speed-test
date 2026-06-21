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
                    title: "Starter credits",
                    creditsDelta: seedCredits,
                    createdAt: .now,
                    note: "Seeded locally for the open-source demo quota flow."
                )
            ]
            self.message = "Granted \(seedCredits) starter credits"
            persist()
        } else {
            self.balance = userDefaults.integer(forKey: balanceKey)
            self.transactions = Self.decodeTransactions(from: userDefaults.data(forKey: transactionsKey))
            self.message = "Credit ledger loaded"
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
            message = "Daily limit reached for \(profile.name)"
            return false
        }
        guard hasEnoughCredits(for: profile) else {
            message = "Not enough credits to run \(profile.name)"
            return false
        }

        balance -= profile.creditsRequired
        appendTransaction(
            kind: .speedTestDebit,
            profile: profile,
            title: profile.name,
            creditsDelta: -profile.creditsRequired,
            note: "Credits reserved before the speed test starts."
        )
        message = "Reserved \(profile.creditsRequired) credits. Starting \(profile.name)."
        return true
    }

    func refundCredits(for profile: MeteredTestProfile, reason: String) {
        guard profile.creditsRequired > 0 else { return }

        balance += profile.creditsRequired
        appendTransaction(
            kind: .speedTestRefund,
            profile: profile,
            title: "\(profile.name) refund",
            creditsDelta: profile.creditsRequired,
            note: reason
        )
        message = "\(profile.name) failed. Returned \(profile.creditsRequired) credits."
    }

    func addCredits(from pack: CreditPack) {
        balance += pack.credits
        appendTransaction(
            kind: .purchase,
            profile: nil,
            title: pack.name,
            creditsDelta: pack.credits,
            note: "Local demo top-up. A real deployment should write this through a server ledger."
        )
        message = "Added \(pack.credits) demo credits"
    }

    func addMembershipCredits(_ credits: Int, planName: String) {
        balance += credits
        appendTransaction(
            kind: .membershipGrant,
            profile: nil,
            title: "\(planName) credits",
            creditsDelta: credits,
            note: "Local demo grant for advanced mode. A real deployment should enforce this on the server."
        )
        message = "\(planName) granted \(credits) credits"
    }

    func loadScreenshotPreview() {
        balance = 5
        transactions = [
            CreditTransaction(
                id: UUID(),
                kind: .speedTestRefund,
                profileID: "standard-speed",
                title: "Standard speed test refund",
                creditsDelta: 1,
                createdAt: .now,
                note: "Speed test request failed. Reserved credits were returned automatically."
            ),
            CreditTransaction(
                id: UUID(),
                kind: .speedTestDebit,
                profileID: "standard-speed",
                title: "Standard speed test",
                creditsDelta: -1,
                createdAt: .now.addingTimeInterval(-120),
                note: "Credits reserved before the speed test starts."
            ),
            CreditTransaction(
                id: UUID(),
                kind: .purchase,
                profileID: nil,
                title: "Starter credits",
                creditsDelta: 6,
                createdAt: .now.addingTimeInterval(-3600),
                note: "Seeded locally for the open-source demo quota flow."
            )
        ]
        message = "Standard speed test failed. Returned 1 credit."
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
