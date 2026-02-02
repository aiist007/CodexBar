import CodexBarMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum AntigravityProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .antigravity,
            metadata: ProviderMetadata(
                id: .antigravity,
                displayName: "Antigravity",
                sessionLabel: "Claude",
                weeklyLabel: "Gemini Pro",
                opusLabel: "Gemini Flash",
                supportsOpus: true,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Antigravity usage (experimental)",
                cliName: "antigravity",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: nil,
                statusPageURL: nil,
                statusLinkURL: "https://www.google.com/appsstatus/dashboard/products/npdyhgECDJ6tB66MxXyo/history",
                statusWorkspaceProductID: "npdyhgECDJ6tB66MxXyo"),
            branding: ProviderBranding(
                iconStyle: .antigravity,
                iconResourceName: "ProviderIcon-antigravity",
                color: ProviderColor(red: 96 / 255, green: 186 / 255, blue: 126 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Antigravity cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in
                    [AntigravityOAuthQuotaFetchStrategy(), AntigravityStatusFetchStrategy()]
                })),
            cli: ProviderCLIConfig(
                name: "antigravity",
                versionDetector: nil))
    }
}

struct AntigravityOAuthQuotaFetchStrategy: ProviderFetchStrategy {
    let id: String = "antigravity.oauth"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        if context.env["ANTIGRAVITY_REFRESH_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return true
        }
        return OpenCodeAuthStore().loadActiveAntigravityAccount() != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        let store = OpenCodeAuthStore()
        let probe = AntigravityOAuthQuotaProbe(timeout: context.webTimeout)

        var lastError: Error?
        for account in try self.resolveAccounts(context: context, store: store) {
            do {
                let snap = try await probe.fetch(account: account)
                let usage = try snap.toUsageSnapshot()
                return self.makeResult(usage: usage, sourceLabel: "oauth")
            } catch {
                lastError = error
                if self.isInvalidGrant(error) {
                    continue
                }
                throw error
            }
        }

        throw lastError ?? AntigravityStatusProbeError.apiError("No Antigravity account available")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        true
    }

    private func resolveAccounts(context: ProviderFetchContext, store: OpenCodeAuthStore) throws
        -> [OpenCodeAuthStore.AntigravityAccount]
    {
        var out: [OpenCodeAuthStore.AntigravityAccount] = []

        let active = store.loadActiveAntigravityAccount()
        if let refresh = context.env["ANTIGRAVITY_REFRESH_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !refresh.isEmpty
        {
            let accounts = store.loadAntigravityAccounts()
            if let match = accounts.first(where: { $0.refreshToken == refresh }) {
                out.append(match)
            } else {
                out.append(OpenCodeAuthStore.AntigravityAccount(
                    email: "Imported",
                    refreshToken: refresh,
                    projectId: nil,
                    managedProjectId: nil))
            }
        }

        if let active, !out.contains(where: { $0.refreshToken == active.refreshToken }) {
            out.append(active)
        }

        if out.isEmpty {
            throw AntigravityStatusProbeError.apiError("No Antigravity account available")
        }
        return out
    }

    private func isInvalidGrant(_ error: Error) -> Bool {
        let text = error.localizedDescription.lowercased()
        return text.contains("invalid_grant")
    }
}

struct AntigravityStatusFetchStrategy: ProviderFetchStrategy {
    let id: String = "antigravity.local"
    let kind: ProviderFetchKind = .localProbe

    func isAvailable(_: ProviderFetchContext) async -> Bool { true }

    func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
        let probe = AntigravityStatusProbe()
        let snap = try await probe.fetch()
        let usage = try snap.toUsageSnapshot()
        return self.makeResult(
            usage: usage,
            sourceLabel: "local")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}
