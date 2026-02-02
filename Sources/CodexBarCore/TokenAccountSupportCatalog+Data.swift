import Foundation

extension TokenAccountSupportCatalog {
    static let supportByProvider: [UsageProvider: TokenAccountSupport] = [
        .codex: TokenAccountSupport(
            title: "Session tokens",
            subtitle: "Store OpenAI Cookie headers.",
            placeholder: "Cookie: …",
            injection: .cookieHeader,
            requiresManualCookieSource: true,
            cookieName: nil),
        .claude: TokenAccountSupport(
            title: "Session tokens",
            subtitle: "Store Claude sessionKey cookies or OAuth access tokens.",
            placeholder: "Paste sessionKey or OAuth token…",
            injection: .cookieHeader,
            requiresManualCookieSource: true,
            cookieName: "sessionKey"),
        .zai: TokenAccountSupport(
            title: "API tokens",
            subtitle: "Stored in the CodexBar config file.",
            placeholder: "Paste token…",
            injection: .environment(key: ZaiSettingsReader.apiTokenKey),
            requiresManualCookieSource: false,
            cookieName: nil),
        .cursor: TokenAccountSupport(
            title: "Session tokens",
            subtitle: "Store multiple Cursor Cookie headers.",
            placeholder: "Cookie: …",
            injection: .cookieHeader,
            requiresManualCookieSource: true,
            cookieName: nil),
        .opencode: TokenAccountSupport(
            title: "Session tokens",
            subtitle: "Store multiple OpenCode Cookie headers.",
            placeholder: "Cookie: …",
            injection: .cookieHeader,
            requiresManualCookieSource: true,
            cookieName: nil),
        .factory: TokenAccountSupport(
            title: "Session tokens",
            subtitle: "Store multiple Factory Cookie headers.",
            placeholder: "Cookie: …",
            injection: .cookieHeader,
            requiresManualCookieSource: true,
            cookieName: nil),
        .minimax: TokenAccountSupport(
            title: "Session tokens",
            subtitle: "Store multiple MiniMax Cookie headers.",
            placeholder: "Cookie: …",
            injection: .cookieHeader,
            requiresManualCookieSource: true,
            cookieName: nil),
        .augment: TokenAccountSupport(
            title: "Session tokens",
            subtitle: "Store multiple Augment Cookie headers.",
            placeholder: "Cookie: …",
            injection: .cookieHeader,
            requiresManualCookieSource: true,
            cookieName: nil),
        .antigravity: TokenAccountSupport(
            title: "Accounts",
            subtitle: "Store multiple Antigravity refresh tokens.",
            placeholder: "Refresh Token…",
            injection: .environment(key: "ANTIGRAVITY_REFRESH_TOKEN"),
            requiresManualCookieSource: false,
            cookieName: nil),
        .gemini: TokenAccountSupport(
            title: "Accounts",
            subtitle: "Store multiple Gemini accounts (Antigravity refresh tokens).",
            placeholder: "Refresh Token…",
            injection: .environment(key: "ANTIGRAVITY_REFRESH_TOKEN"),
            requiresManualCookieSource: false,
            cookieName: nil),
        .nvidia: TokenAccountSupport(
            title: "API Keys",
            subtitle: "Store multiple NVIDIA API keys.",
            placeholder: "API Key…",
            injection: .environment(key: "NVIDIA_API_KEY"),
            requiresManualCookieSource: false,
            cookieName: nil),
    ]
}
