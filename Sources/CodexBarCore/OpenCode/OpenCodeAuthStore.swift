import Foundation

public struct OpenCodeAuthStore: Sendable {
    public struct ProviderAuthEntry: Decodable, Sendable {
        public let type: String?
        public let refresh: String?
        public let access: String?
        public let expires: Int?
        public let accountId: String?
        public let key: String?
    }

    public struct AuthFile: Decodable, Sendable {
        public let antigravity: ProviderAuthEntry?
        public let google: ProviderAuthEntry?
        public let openai: ProviderAuthEntry?
        public let perplexity: ProviderAuthEntry?
        public let nebula: ProviderAuthEntry?
        public let opencode: ProviderAuthEntry?
        public let nvidia: ProviderAuthEntry?
    }

    public struct AntigravityAccount: Decodable, Sendable {
        public let email: String
        public let refreshToken: String
        public let projectId: String?
        public let managedProjectId: String?
    }

    public struct AntigravityAccountsFile: Decodable, Sendable {
        public let accounts: [AntigravityAccount]
        public let activeIndex: Int?
    }

    public init() {}

    public func loadAuthFile() -> AuthFile? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/opencode/auth.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AuthFile.self, from: data)
    }

    public func loadAntigravityAccounts() -> [AntigravityAccount] {
        self.loadAntigravityAccountsFile()?.accounts ?? []
    }

    public func loadAntigravityAccountsFile() -> AntigravityAccountsFile? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opencode/antigravity-accounts.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AntigravityAccountsFile.self, from: data)
    }

    public func loadActiveAntigravityAccount() -> AntigravityAccount? {
        guard let file = self.loadAntigravityAccountsFile(), !file.accounts.isEmpty else { return nil }
        let index = file.activeIndex ?? 0
        let clamped = min(max(index, 0), file.accounts.count - 1)
        return file.accounts[clamped]
    }
}
