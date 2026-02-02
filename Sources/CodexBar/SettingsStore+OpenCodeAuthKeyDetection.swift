import CodexBarCore

extension SettingsStore {
    func applyOpenCodeAuthKeyAutoEnableIfNeeded() {
        let auth = OpenCodeAuthStore().loadAuthFile()
        let hasOpenCodeKey = (auth?.opencode?.key?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        let hasNvidiaKey = (auth?.nvidia?.key?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)

        if hasOpenCodeKey {
            let existing = self.config.providerConfig(for: .opencode)
            if existing == nil || existing?.enabled == nil {
                self.updateProviderConfig(provider: .opencode) { entry in
                    entry.enabled = true
                }
            }
        }

        if hasNvidiaKey {
            let existing = self.config.providerConfig(for: .nvidia)
            if existing == nil || existing?.enabled == nil {
                self.updateProviderConfig(provider: .nvidia) { entry in
                    entry.enabled = true
                }
            }
        }
    }
}
