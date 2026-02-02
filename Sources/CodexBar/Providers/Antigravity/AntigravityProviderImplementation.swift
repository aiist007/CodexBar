import CodexBarCore
import CodexBarMacroSupport
import Foundation
import SwiftUI

@ProviderImplementationRegistration
struct AntigravityProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .antigravity

    func detectVersion(context _: ProviderVersionContext) async -> String? {
        await AntigravityStatusProbe.detectVersion()
    }

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        let store = OpenCodeAuthStore()
        let file = store.loadAntigravityAccountsFile()
        let accounts = file?.accounts ?? []
        let subtitle = accounts.isEmpty ? "No OpenCode accounts found." : "OpenCode accounts: \(accounts.count)"

        return [
            ProviderSettingsFieldDescriptor(
                id: "antigravity-opencode-import",
                title: "OpenCode integration",
                subtitle: subtitle,
                kind: .plain,
                placeholder: nil,
                binding: Binding.constant(""),
                actions: [
                    ProviderSettingsActionDescriptor(
                        id: "antigravity-import-open-code",
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
                                provider: .antigravity,
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
        await context.controller.runAntigravityLoginFlow()
        return false
    }
}
