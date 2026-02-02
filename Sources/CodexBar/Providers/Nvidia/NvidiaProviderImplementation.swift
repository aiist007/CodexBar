import CodexBarCore
import CodexBarMacroSupport
import Foundation
import SwiftUI

@ProviderImplementationRegistration
struct NvidiaProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .nvidia

    @MainActor
    func observeSettings(_ settings: SettingsStore) {
    }

    @MainActor
    func settingsFields(context _: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        let authStore = OpenCodeAuthStore()
        let auth = authStore.loadAuthFile()
        let nvidiaKeyBinding = Binding(
            get: { authStore.loadAuthFile()?.nvidia?.key ?? "" },
            set: { _ in })

        return [
            ProviderSettingsFieldDescriptor(
                id: "nvidia-api-key",
                title: "API key",
                subtitle: "From OpenCode auth store.",
                kind: .secure,
                placeholder: nil,
                binding: nvidiaKeyBinding,
                actions: [],
                isVisible: { (auth?.nvidia?.key?.isEmpty == false) },
                onActivate: nil),
        ]
    }
}
