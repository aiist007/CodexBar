import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AntigravityOAuthQuotaProbe: Sendable {
    public var timeout: TimeInterval = 10.0
    public var dataLoader: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public init(
        timeout: TimeInterval = 10.0,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        })
    {
        self.timeout = timeout
        self.dataLoader = dataLoader
    }

    public func fetch(account: OpenCodeAuthStore.AntigravityAccount) async throws -> AntigravityStatusSnapshot {
        let refreshToken = account.refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !refreshToken.isEmpty else {
            throw AntigravityStatusProbeError.apiError("Missing refresh token")
        }

        let accessToken = try await AntigravityOAuthQuotaProbe.refreshAccessToken(
            refreshToken: refreshToken,
            timeout: self.timeout,
            dataLoader: self.dataLoader)

        let modelsResponse = try await AntigravityOAuthQuotaProbe.fetchAvailableModels(
            accessToken: accessToken,
            projectId: account.managedProjectId ?? account.projectId,
            timeout: self.timeout,
            dataLoader: self.dataLoader)

        let quotas = AntigravityOAuthQuotaProbe.aggregateQuota(models: modelsResponse.models)
        return AntigravityStatusSnapshot(
            modelQuotas: quotas,
            accountEmail: account.email,
            accountPlan: nil)
    }

    private struct OAuthRefreshResponse: Decodable {
        let access_token: String?
        let expires_in: Double?
        let id_token: String?
        let refresh_token: String?
    }

    private struct OAuthErrorResponse: Decodable {
        let error: String?
        let error_description: String?
    }

    private static func refreshAccessToken(
        refreshToken: String,
        timeout: TimeInterval,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) async throws -> String
    {
        let (clientId, clientSecret) = try Self.loadAntigravityClientCredentials()
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw AntigravityStatusProbeError.apiError("Invalid token endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components: [String] = []
        components.append("grant_type=refresh_token")
        components.append("refresh_token=\(Self.formEscape(refreshToken))")
        components.append("client_id=\(Self.formEscape(clientId))")
        components.append("client_secret=\(Self.formEscape(clientSecret))")
        request.httpBody = components.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await dataLoader(request)
        guard let http = response as? HTTPURLResponse else {
            throw AntigravityStatusProbeError.apiError("Invalid token response")
        }
        guard http.statusCode == 200 else {
            let errorPayload = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data)
            let error = errorPayload?.error?.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = errorPayload?.error_description?.trimmingCharacters(in: .whitespacesAndNewlines)
            var details = "Token refresh HTTP \(http.statusCode)"
            if let error, !error.isEmpty {
                details += ": \(error)"
            }
            if let description, !description.isEmpty {
                details += " (\(description))"
            }
            throw AntigravityStatusProbeError.apiError(details)
        }
        let payload = try JSONDecoder().decode(OAuthRefreshResponse.self, from: data)
        guard let access = payload.access_token, !access.isEmpty else {
            throw AntigravityStatusProbeError.apiError("Token refresh missing access token")
        }
        return access
    }

    private struct FetchAvailableModelsResponse: Decodable {
        let models: [String: FetchAvailableModelEntry]?
    }

    private struct FetchAvailableModelEntry: Decodable {
        let modelName: String?
        let displayName: String?
        let quotaInfo: FetchAvailableModelQuotaInfo?
    }

    private struct FetchAvailableModelQuotaInfo: Decodable {
        let remainingFraction: Double?
        let resetTime: String?
    }

    private static func fetchAvailableModels(
        accessToken: String,
        projectId: String?,
        timeout: TimeInterval,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) async throws
        -> FetchAvailableModelsResponse
    {
        let endpoint = try Self.loadAntigravityProdEndpoint()
        guard let url = URL(string: "\(endpoint)/v1internal:fetchAvailableModels") else {
            throw AntigravityStatusProbeError.apiError("Invalid Antigravity endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout

        let headers = Self.loadAntigravityHeaders()
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let projectId, !projectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["project": projectId], options: [])
        } else {
            request.httpBody = Data("{}".utf8)
        }

        let (data, response) = try await dataLoader(request)
        guard let http = response as? HTTPURLResponse else {
            throw AntigravityStatusProbeError.apiError("Invalid response")
        }
        guard http.statusCode == 200 else {
            throw AntigravityStatusProbeError.apiError("HTTP \(http.statusCode)")
        }
        return try JSONDecoder().decode(FetchAvailableModelsResponse.self, from: data)
    }

    private struct GroupState {
        var remainingFraction: Double?
        var resetTime: String?
    }

    private static func aggregateQuota(models: [String: FetchAvailableModelEntry]?) -> [AntigravityModelQuota] {
        guard let models else { return [] }

        var claude = GroupState()
        var geminiPro = GroupState()
        var geminiFlash = GroupState()

        for (modelName, entry) in models {
            let displayName = entry.displayName ?? entry.modelName
            let group = Self.classifyQuotaGroup(modelName: modelName, displayName: displayName)
            guard let group else { continue }

            let fraction = Self.normalizeRemainingFraction(entry.quotaInfo?.remainingFraction)
            let reset = entry.quotaInfo?.resetTime

            switch group {
            case .claude:
                Self.updateGroup(&claude, fraction: fraction, resetTime: reset)
            case .geminiPro:
                Self.updateGroup(&geminiPro, fraction: fraction, resetTime: reset)
            case .geminiFlash:
                Self.updateGroup(&geminiFlash, fraction: fraction, resetTime: reset)
            }
        }

        return [
            Self.makeQuota(label: "Claude", modelId: "claude", state: claude),
            Self.makeQuota(label: "Gemini Pro", modelId: "gemini-pro", state: geminiPro),
            Self.makeQuota(label: "Gemini Flash", modelId: "gemini-flash", state: geminiFlash),
        ].compactMap { $0 }
    }

    private enum QuotaGroup {
        case claude
        case geminiPro
        case geminiFlash
    }

    private static func classifyQuotaGroup(modelName: String, displayName: String?) -> QuotaGroup? {
        let combined = (modelName + " " + (displayName ?? "")).lowercased()
        if combined.contains("claude") {
            return .claude
        }
        let isGemini3 = combined.contains("gemini-3") || combined.contains("gemini 3")
        if !isGemini3 { return nil }
        if combined.contains("flash") {
            return .geminiFlash
        }
        return .geminiPro
    }

    private static func normalizeRemainingFraction(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        if value < 0 { return 0 }
        if value > 1 { return 1 }
        return value
    }

    private static func updateGroup(_ group: inout GroupState, fraction: Double?, resetTime: String?) {
        if let fraction {
            if let existing = group.remainingFraction {
                group.remainingFraction = min(existing, fraction)
            } else {
                group.remainingFraction = fraction
            }
        }

        guard let resetTime, let candidate = Self.parseResetTime(resetTime) else { return }
        if let existing = group.resetTime, let existingDate = Self.parseResetTime(existing) {
            if candidate < existingDate {
                group.resetTime = resetTime
            }
        } else {
            group.resetTime = resetTime
        }
    }

    private static func makeQuota(label: String, modelId: String, state: GroupState) -> AntigravityModelQuota? {
        if state.remainingFraction == nil, state.resetTime == nil {
            return nil
        }
        let resetDate = state.resetTime.flatMap { Self.parseResetTime($0) }
        let resetDesc = state.resetTime.flatMap { Self.formatResetTime($0) }
        return AntigravityModelQuota(
            label: label,
            modelId: modelId,
            remainingFraction: state.remainingFraction,
            resetTime: resetDate,
            resetDescription: resetDesc)
    }

    private static func parseResetTime(_ isoString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: isoString)
    }

    private static func formatResetTime(_ isoString: String) -> String {
        guard let resetDate = Self.parseResetTime(isoString) else {
            return "Resets soon"
        }
        let interval = resetDate.timeIntervalSince(Date())
        if interval <= 0 { return "Resets soon" }
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        }
        return "Resets in \(minutes)m"
    }

    private static func formEscape(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return (value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)
            .replacingOccurrences(of: "%20", with: "+")
    }

    private static func loadAntigravityClientCredentials() throws -> (String, String) {
        let constants = try Self.loadAntigravityConstantsText()
        guard let clientId = Self.matchStringConstant(name: "ANTIGRAVITY_CLIENT_ID", in: constants),
              let clientSecret = Self.matchStringConstant(name: "ANTIGRAVITY_CLIENT_SECRET", in: constants)
        else {
            throw AntigravityStatusProbeError.apiError("Missing Antigravity OAuth client credentials")
        }
        return (clientId, clientSecret)
    }

    private static func loadAntigravityProdEndpoint() throws -> String {
        let constants = try Self.loadAntigravityConstantsText()
        guard let endpoint = Self.matchStringConstant(name: "ANTIGRAVITY_ENDPOINT_PROD", in: constants) else {
            throw AntigravityStatusProbeError.apiError("Missing Antigravity prod endpoint")
        }
        return endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loadAntigravityHeaders() -> [String: String] {
        guard let constants = try? Self.loadAntigravityConstantsText() else { return [:] }
        var out: [String: String] = [:]
        if let userAgent = Self.matchObjectStringField(objectName: "ANTIGRAVITY_HEADERS", fieldName: "User-Agent", in: constants) {
            out["User-Agent"] = userAgent
        }
        if let apiClient = Self.matchObjectStringField(objectName: "ANTIGRAVITY_HEADERS", fieldName: "X-Goog-Api-Client", in: constants) {
            out["X-Goog-Api-Client"] = apiClient
        }
        if let metadata = Self.matchObjectStringField(objectName: "ANTIGRAVITY_HEADERS", fieldName: "Client-Metadata", in: constants) {
            out["Client-Metadata"] = metadata
        }
        return out
    }

    private static func loadAntigravityConstantsText() throws -> String {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opencode/node_modules/opencode-antigravity-auth/dist/src/constants.js")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw AntigravityStatusProbeError.apiError("OpenCode Antigravity plugin not found")
        }
        return text
    }

    private static func matchStringConstant(name: String, in text: String) -> String? {
        let pattern = #"export\s+const\s+"# + name + #"\s*=\s*\"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let valueRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[valueRange])
    }

    private static func matchObjectStringField(objectName: String, fieldName: String, in text: String) -> String? {
        let objectPattern = #"export\s+const\s+"# + objectName + #"\s*=\s*\{([\s\S]*?)\}\s*;"#
        guard let objectRegex = try? NSRegularExpression(pattern: objectPattern) else { return nil }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let objMatch = objectRegex.firstMatch(in: text, options: [], range: fullRange),
              objMatch.numberOfRanges >= 2,
              let objBodyRange = Range(objMatch.range(at: 1), in: text)
        else { return nil }
        let body = String(text[objBodyRange])

        let fieldPattern = #"\""# + NSRegularExpression.escapedPattern(for: fieldName) + #"\"\s*:\s*\"([^\"]+)\""#
        guard let fieldRegex = try? NSRegularExpression(pattern: fieldPattern) else { return nil }
        let bodyRange = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let fieldMatch = fieldRegex.firstMatch(in: body, options: [], range: bodyRange),
              fieldMatch.numberOfRanges >= 2,
              let valueRange = Range(fieldMatch.range(at: 1), in: body)
        else { return nil }
        return String(body[valueRange])
    }
}
