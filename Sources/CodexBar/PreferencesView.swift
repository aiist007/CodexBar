import AppKit
import CodexBarCore
import SwiftUI

enum PreferencesTab: String, Hashable {
    case general
    case dashboard
    case providers
    case display
    case advanced
    case about
    case debug

    static let defaultWidth: CGFloat = 496
    static let providersWidth: CGFloat = 720
    static let windowHeight: CGFloat = 580

    var preferredWidth: CGFloat {
        (self == .providers || self == .dashboard) ? PreferencesTab.providersWidth : PreferencesTab.defaultWidth
    }

    var preferredHeight: CGFloat { PreferencesTab.windowHeight }
}

// MARK: - Accounts

@MainActor
private struct PreferencesAccountsPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var isRefreshingAll = false
    @State private var refreshingProviders: Set<UsageProvider> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accounts")
                        .font(.headline)
                    Text("Token accounts configured in CodexBar (including OpenCode-imported accounts when available).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button("Refresh all") {
                        Task {
                            await self.refreshAllProviders()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(self.isRefreshingAll)

                    Button("Reload from disk") {
                        self.settings.reloadTokenAccounts()
                    }
                    .buttonStyle(.bordered)

                    Button("Open config") {
                        self.settings.openTokenAccountsFile()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }

                if self.providerGroups.isEmpty {
                    Text("No token accounts configured")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(self.providerGroups, id: \.provider) { group in
                            AccountsProviderCard(
                                provider: group.provider,
                                accounts: group.accounts,
                                snapshots: self.store.accountSnapshots[group.provider] ?? [],
                                mainSnapshot: self.store.snapshot(for: group.provider),
                                mainError: self.store.error(for: group.provider),
                                providerRefreshing: self.refreshingProviders.contains(group.provider),
                                showUsed: self.settings.usageBarsShowUsed,
                                resetStyle: self.settings.resetTimeDisplayStyle,
                                hidePersonalInfo: self.settings.hidePersonalInfo,
                                onRefresh: {
                                    Task { await self.refreshProvider(group.provider) }
                                })
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct ProviderGroup {
        let provider: UsageProvider
        let accounts: [ProviderTokenAccount]
    }

    private var providerGroups: [ProviderGroup] {
        var out: [ProviderGroup] = []
        for provider in UsageProvider.allCases {
            var accounts = self.store.tokenAccounts(for: provider)
            
            if (provider == .opencode || provider == .nvidia), accounts.isEmpty {
                let hasSnapshot = self.store.snapshot(for: provider) != nil
                let meta = ProviderDescriptorRegistry.descriptor(for: provider).metadata
                let isEnabled = self.settings.isProviderEnabled(provider: provider, metadata: meta)
                
                if hasSnapshot || isEnabled {
                    let uuid = UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", provider.hashValue))") ?? UUID()
                    let label: String = if let snapshot = self.store.snapshot(for: provider) {
                        snapshot.identity?.accountOrganization ?? snapshot.identity?.accountEmail ?? "Default Key"
                    } else {
                        "Default Key"
                    }
                    
                    let virtual = ProviderTokenAccount(
                        id: uuid,
                        label: label,
                        token: "redacted-virtual",
                        addedAt: 0,
                        lastUsed: nil)
                    accounts = [virtual]
                }
            }

            if accounts.isEmpty { continue }
            out.append(ProviderGroup(provider: provider, accounts: accounts))
        }
        return out
    }

    private func refreshAllProviders() async {
        if self.isRefreshingAll { return }
        self.isRefreshingAll = true
        defer { self.isRefreshingAll = false }

        for group in self.providerGroups {
            await self.refreshProvider(group.provider)
        }
    }

    private func refreshProvider(_ provider: UsageProvider) async {
        if self.refreshingProviders.contains(provider) { return }
        self.refreshingProviders.insert(provider)
        defer { self.refreshingProviders.remove(provider) }

        let accounts = self.store.tokenAccounts(for: provider)
        guard !accounts.isEmpty else { return }
        await self.store.refreshTokenAccounts(provider: provider, accounts: accounts)
    }
}

private struct AccountsProviderCard: View {
    let provider: UsageProvider
    let accounts: [ProviderTokenAccount]
    let snapshots: [TokenAccountUsageSnapshot]
    let mainSnapshot: UsageSnapshot?
    let mainError: String?
    let providerRefreshing: Bool
    let showUsed: Bool
    let resetStyle: ResetTimeDisplayStyle
    let hidePersonalInfo: Bool
    let onRefresh: () -> Void

    var body: some View {
        let meta = ProviderDescriptorRegistry.descriptor(for: self.provider).metadata
        let color = ProviderDescriptorRegistry.descriptor(for: self.provider).branding.color
        let tint = Color(red: color.red, green: color.green, blue: color.blue)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                if let image = ProviderBrandIcon.image(for: self.provider) {
                    Image(nsImage: image)
                        .foregroundStyle(.primary)
                }
                Text(meta.displayName)
                    .font(.body)
                    .fontWeight(.semibold)
                Text("(\(self.accounts.count))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(self.providerRefreshing ? "Refreshing…" : "Refresh") {
                    self.onRefresh()
                }
                .buttonStyle(.bordered)
                .disabled(self.providerRefreshing)
            }

            VStack(spacing: 8) {
                ForEach(self.accounts, id: \.id) { account in
                    self.accountRow(account: account, meta: meta, tint: tint)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
    }

    private func accountRow(account: ProviderTokenAccount, meta: ProviderMetadata, tint: Color) -> some View {
        let found = self.snapshots.first(where: { $0.account.id == account.id })
        let effectiveSnapshot: TokenAccountUsageSnapshot? = if let found {
            found
        } else if (self.provider == .opencode || self.provider == .nvidia),
                  let main = self.mainSnapshot
        {
            TokenAccountUsageSnapshot(account: account, snapshot: main, error: self.mainError, sourceLabel: nil)
        } else {
            nil
        }

        return AccountsAccountRow(
            provider: self.provider,
            account: account,
            snapshot: effectiveSnapshot,
            meta: meta,
            showUsed: self.showUsed,
            resetStyle: self.resetStyle,
            tint: tint,
            hidePersonalInfo: self.hidePersonalInfo)
    }
}

private struct AccountsAccountRow: View {
    let provider: UsageProvider
    let account: ProviderTokenAccount
    let snapshot: TokenAccountUsageSnapshot?
    let meta: ProviderMetadata
    let showUsed: Bool
    let resetStyle: ResetTimeDisplayStyle
    let tint: Color
    let hidePersonalInfo: Bool

    var body: some View {
        let label = PersonalInfoRedactor.redactEmails(in: self.account.label, isEnabled: self.hidePersonalInfo)
            ?? self.account.label
        let error = self.snapshot?.error
        let usage = self.snapshot?.snapshot

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.footnote)
                    .lineLimit(1)
                Spacer()
                if let error, !error.isEmpty {
                    Text("Error")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .help(PersonalInfoRedactor.redactEmails(in: error, isEnabled: self.hidePersonalInfo) ?? "")
                } else if usage == nil {
                    Text("Not fetched")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let primary = usage?.primary {
                AccountsMetricRow(
                    title: self.meta.sessionLabel,
                    window: primary,
                    showUsed: self.showUsed,
                    resetStyle: self.resetStyle,
                    tint: self.tint)
            }

            if let secondary = usage?.secondary {
                AccountsMetricRow(
                    title: self.meta.weeklyLabel,
                    window: secondary,
                    showUsed: self.showUsed,
                    resetStyle: self.resetStyle,
                    tint: self.tint)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct AccountsMetricRow: View {
    let title: String
    let window: RateWindow
    let showUsed: Bool
    let resetStyle: ResetTimeDisplayStyle
    let tint: Color

    var body: some View {
        let percent = self.showUsed ? self.window.usedPercent : self.window.remainingPercent
        let reset = UsageFormatter.resetLine(for: self.window, style: self.resetStyle, now: Date())
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(self.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let reset {
                    Text(reset)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            UsageProgressBar(percent: percent, tint: self.tint, accessibilityLabel: self.title)
        }
    }
}

@MainActor
struct PreferencesView: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    let updater: UpdaterProviding
    @Bindable var selection: PreferencesSelection
    @State private var contentWidth: CGFloat = PreferencesTab.general.preferredWidth
    @State private var contentHeight: CGFloat = PreferencesTab.general.preferredHeight

    var body: some View {
        TabView(selection: self.$selection.tab) {
            GeneralPane(settings: self.settings, store: self.store)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(PreferencesTab.general)

            PreferencesAccountsPane(settings: self.settings, store: self.store)
                .tabItem { Label("Accounts", systemImage: "person.2") }
                .tag(PreferencesTab.dashboard)

            ProvidersPane(settings: self.settings, store: self.store)
                .tabItem { Label("Providers", systemImage: "square.grid.2x2") }
                .tag(PreferencesTab.providers)

            DisplayPane(settings: self.settings)
                .tabItem { Label("Display", systemImage: "eye") }
                .tag(PreferencesTab.display)

            AdvancedPane(settings: self.settings)
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
                .tag(PreferencesTab.advanced)

            AboutPane(updater: self.updater)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(PreferencesTab.about)

            if self.settings.debugMenuEnabled {
                DebugPane(settings: self.settings, store: self.store)
                    .tabItem { Label("Debug", systemImage: "ladybug") }
                    .tag(PreferencesTab.debug)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: self.contentWidth, height: self.contentHeight)
        .onAppear {
            self.updateLayout(for: self.selection.tab, animate: false)
            self.ensureValidTabSelection()
        }
        .onChange(of: self.selection.tab) { _, newValue in
            self.updateLayout(for: newValue, animate: true)
        }
        .onChange(of: self.settings.debugMenuEnabled) { _, _ in
            self.ensureValidTabSelection()
        }
    }

    private func updateLayout(for tab: PreferencesTab, animate: Bool) {
        let change = {
            self.contentWidth = tab.preferredWidth
            self.contentHeight = tab.preferredHeight
        }
        if animate {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { change() }
        } else {
            change()
        }
    }

    private func ensureValidTabSelection() {
        if !self.settings.debugMenuEnabled, self.selection.tab == .debug {
            self.selection.tab = .general
            self.updateLayout(for: .general, animate: true)
        }
    }
}
