import CodexBarCore
import CodexBarMacroSupport
import Foundation
import SwiftUI

@ProviderImplementationRegistration
struct GeminiProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .gemini
    let supportsLoginFlow: Bool = true

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        let store = OpenCodeAuthStore()
        let file = store.loadAntigravityAccountsFile()
        let accounts = file?.accounts ?? []
        let subtitle = accounts.isEmpty ? "No OpenCode accounts found." : "OpenCode accounts: \(accounts.count)"

        return [
            ProviderSettingsFieldDescriptor(
                id: "gemini-opencode-import",
                title: "OpenCode integration",
                subtitle: subtitle,
                kind: .plain,
                placeholder: nil,
                binding: .constant(""),
                actions: [
                    ProviderSettingsActionDescriptor(
                        id: "gemini-import-open-code",
                        title: "Import accounts",
                        style: .bordered,
                        isVisible: { !accounts.isEmpty },
                        perform: {
                            let file = OpenCodeAuthStore().loadAntigravityAccountsFile()
                            let fetched = file?.accounts ?? []
                            guard !fetched.isEmpty else { return }

                            var preferred: String?
                            if let idx = file?.activeIndex,
                               idx >= 0,
                               idx < fetched.count
                            {
                                preferred = fetched[idx].email
                            }

                            var imported: [(label: String, token: String)] = []
                            imported.reserveCapacity(fetched.count)
                            for account in fetched {
                                imported.append((label: account.email, token: account.refreshToken))
                            }

                            context.settings.syncTokenAccounts(
                                provider: .gemini,
                                imported: imported,
                                preferredActiveLabel: preferred)
                        }),
                ],
                isVisible: nil,
                onActivate: nil),
        ]
    }

    @MainActor
    func runLoginFlow(context: ProviderLoginContext) async -> Bool {
        await context.controller.runGeminiLoginFlow()
        return false
    }
}
