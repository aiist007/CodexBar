import CodexBarMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum NvidiaProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .nvidia,
            metadata: ProviderMetadata(
                id: .nvidia,
                displayName: "NVIDIA",
                sessionLabel: "Session",
                weeklyLabel: "Weekly",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show NVIDIA usage",
                cliName: "nvidia",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                browserCookieOrder: nil,
                dashboardURL: "https://build.nvidia.com",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .nvidia,
                iconResourceName: "ProviderIcon-nvidia",
                color: ProviderColor(red: 118 / 255, green: 185 / 255, blue: 0 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "NVIDIA cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in
                    [
                        NvidiaNGCQuotaFetchStrategy(),
                        NvidiaAPIKeyPresenceFetchStrategy(),
                    ]
                })),
            cli: ProviderCLIConfig(
                name: "nvidia",
                versionDetector: nil))
    }
}

struct NvidiaNGCQuotaFetchStrategy: ProviderFetchStrategy {
    let id: String = "nvidia.ngc"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_: ProviderFetchContext) async -> Bool {
        let auth = OpenCodeAuthStore().loadAuthFile()
        let key = auth?.nvidia?.key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !key.isEmpty
    }

    func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
        let auth = OpenCodeAuthStore().loadAuthFile()
        let key = auth?.nvidia?.key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if key.isEmpty {
            throw ProviderFetchError.noAvailableStrategy(.nvidia)
        }

        // Best effort: we always return a snapshot so the provider can be rendered.
        let org: NvidiaNGCOrganizationInfo?
        do {
            org = try await NvidiaNGCUsageFetcher.fetchOrgInfo(apiKey: key)
        } catch {
            // Network/API may be blocked by scopes; keep rendering.
            org = nil
        }

        var quota: NvidiaNGCQuotaSummary?
        if let org {
            do {
                let mapping = try await NvidiaNGCUsageFetcher.fetchNcaIdMapping(apiKey: key)
                if let ncaId = mapping[org.orgName] {
                    quota = try await NvidiaNGCUsageFetcher.fetchQuotaSummary(apiKey: key, ncaId: ncaId)
                }
            } catch {
                quota = nil
            }
        }

        let identity = ProviderIdentitySnapshot(
            providerID: .nvidia,
            accountEmail: nil,
            accountOrganization: org?.displayName,
            loginMethod: "apiKey")

        let primary: RateWindow? = quota.map {
            RateWindow(usedPercent: $0.percentUsed, windowMinutes: nil, resetsAt: $0.resetsAt, resetDescription: nil)
        }
        let usage = UsageSnapshot(primary: primary, secondary: nil, updatedAt: Date(), identity: identity)
        return self.makeResult(usage: usage, sourceLabel: "ngc")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        true
    }
}

struct NvidiaAPIKeyPresenceFetchStrategy: ProviderFetchStrategy {
    let id: String = "nvidia.apiKey"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_: ProviderFetchContext) async -> Bool {
        let auth = OpenCodeAuthStore().loadAuthFile()
        let key = auth?.nvidia?.key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !key.isEmpty
    }

    func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
        let auth = OpenCodeAuthStore().loadAuthFile()
        let key = auth?.nvidia?.key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if key.isEmpty {
            throw ProviderFetchError.noAvailableStrategy(.nvidia)
        }
        let identity = ProviderIdentitySnapshot(providerID: .nvidia, accountEmail: nil, accountOrganization: nil, loginMethod: "apiKey")
        let usage = UsageSnapshot(primary: nil, secondary: nil, updatedAt: Date(), identity: identity)
        return self.makeResult(usage: usage, sourceLabel: "api-key")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}
