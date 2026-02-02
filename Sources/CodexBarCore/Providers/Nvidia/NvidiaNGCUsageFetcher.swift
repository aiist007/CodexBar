import Foundation

enum NvidiaNGCUsageError: LocalizedError, Sendable {
    case missingCredentials
    case networkError(String)
    case apiError(String)
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            "Missing NVIDIA API key."
        case let .networkError(details):
            "NVIDIA network error: \(details)"
        case let .apiError(details):
            "NVIDIA API error: \(details)"
        case let .parseFailed(details):
            "NVIDIA parse failed: \(details)"
        }
    }
}

struct NvidiaNGCOrganizationInfo: Sendable {
    let orgName: String
    let displayName: String?
}

struct NvidiaNGCQuotaSummary: Sendable {
    let percentUsed: Double
    let resetsAt: Date?
}

struct NvidiaNGCUsageFetcher {
    private static let baseURL = URL(string: "https://api.ngc.nvidia.com")!

    static func fetchOrgInfo(apiKey: String) async throws -> NvidiaNGCOrganizationInfo {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NvidiaNGCUsageError.missingCredentials
        }

        let url = Self.baseURL.appendingPathComponent("v2/orgs")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NvidiaNGCUsageError.networkError("Invalid response")
        }
        guard http.statusCode == 200 else {
            throw NvidiaNGCUsageError.apiError("HTTP \(http.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data),
              let dictionary = json as? [String: Any],
              let orgs = dictionary["organizations"] as? [[String: Any]],
              let first = orgs.first
        else {
            throw NvidiaNGCUsageError.parseFailed("Unexpected /v2/orgs payload")
        }

        let orgName = (first["name"] as? String) ?? ""
        let displayName = first["displayName"] as? String
        guard !orgName.isEmpty else {
            throw NvidiaNGCUsageError.parseFailed("Missing organization name")
        }

        return NvidiaNGCOrganizationInfo(orgName: orgName, displayName: displayName)
    }

    static func fetchNcaIdMapping(apiKey: String) async throws -> [String: String] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NvidiaNGCUsageError.missingCredentials
        }

        // Official mapping endpoint, but not all keys/scopes can access it.
        let url = Self.baseURL.appendingPathComponent("v2/orgs/ncaIds")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode([String: String]())

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NvidiaNGCUsageError.networkError("Invalid response")
        }
        guard http.statusCode == 200 else {
            throw NvidiaNGCUsageError.apiError("HTTP \(http.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            throw NvidiaNGCUsageError.parseFailed("Invalid JSON")
        }

        var mappings: [[String: Any]] = []
        if let list = json as? [[String: Any]] {
            mappings = list
        } else if let dict = json as? [String: Any] {
            if let items = dict["mappings"] as? [[String: Any]] { mappings = items }
            if let items = dict["orgs"] as? [[String: Any]] { mappings = items }
            if let items = dict["organizations"] as? [[String: Any]] { mappings = items }
            if let items = dict["data"] as? [[String: Any]] { mappings = items }
        }

        var result: [String: String] = [:]
        for item in mappings {
            let orgName = (item["orgName"] as? String) ?? (item["name"] as? String)
            let ncaId = (item["ncaId"] as? String) ?? (item["ncaID"] as? String)
            if let orgName, let ncaId, !orgName.isEmpty, !ncaId.isEmpty {
                result[orgName] = ncaId
            }
        }
        return result
    }

    static func fetchQuotaSummary(apiKey: String, ncaId: String) async throws -> NvidiaNGCQuotaSummary? {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NvidiaNGCUsageError.missingCredentials
        }
        guard !ncaId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let url = Self.baseURL
            .appendingPathComponent("v3/accounts")
            .appendingPathComponent(ncaId)
            .appendingPathComponent("nvcf/quotas")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NvidiaNGCUsageError.networkError("Invalid response")
        }
        guard http.statusCode == 200 else {
            throw NvidiaNGCUsageError.apiError("HTTP \(http.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            throw NvidiaNGCUsageError.parseFailed("Invalid JSON")
        }

        let summary = Self.bestEffortQuotaSummary(from: json)
        return summary
    }

    private static func bestEffortQuotaSummary(from json: Any) -> NvidiaNGCQuotaSummary? {
        let candidates = Self.collectNumericDicts(from: json)
        var best: (percentUsed: Double, resetsAt: Date?)?

        for dict in candidates {
            if let percent = Self.percentUsed(from: dict) {
                let resetsAt = Self.dateValue(in: dict, keys: [
                    "resetsAt",
                    "resetAt",
                    "periodEnd",
                    "expiresAt",
                    "expiry",
                    "expiration",
                ])
                if best == nil || percent > best!.percentUsed {
                    best = (percentUsed: percent, resetsAt: resetsAt)
                }
            }
        }

        guard let best else { return nil }
        return NvidiaNGCQuotaSummary(percentUsed: max(0, min(100, best.percentUsed)), resetsAt: best.resetsAt)
    }

    private static func collectNumericDicts(from json: Any) -> [[String: Any]] {
        var result: [[String: Any]] = []

        func walk(_ x: Any) {
            if let dict = x as? [String: Any] {
                result.append(dict)
                for v in dict.values {
                    walk(v)
                }
                return
            }
            if let list = x as? [Any] {
                for v in list { walk(v) }
            }
        }

        walk(json)
        return result
    }

    private static func percentUsed(from dict: [String: Any]) -> Double? {
        let usedKeys = ["used", "consumed", "usage", "usedQuota", "quotaUsed", "utilized"]
        let remainingKeys = ["remaining", "left", "available", "balance"]
        let limitKeys = ["limit", "quota", "max", "total", "allowed", "quotaLimit"]

        let used = Self.firstDouble(in: dict, keys: usedKeys)
        let remaining = Self.firstDouble(in: dict, keys: remainingKeys)
        let limit = Self.firstDouble(in: dict, keys: limitKeys)

        if let used, let limit, limit > 0 {
            return (used / limit) * 100
        }
        if let remaining, let limit, limit > 0 {
            let used = max(0, limit - remaining)
            return (used / limit) * 100
        }
        if let used, let remaining, used + remaining > 0 {
            let limit = used + remaining
            return (used / limit) * 100
        }
        return nil
    }

    private static func firstDouble(in dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = dict[key], let parsed = Self.double(from: value) {
                return parsed
            }
        }
        return nil
    }

    private static func double(from value: Any) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let i = value as? Int64 { return Double(i) }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func dateValue(in dict: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            guard let value = dict[key] else { continue }
            if let d = value as? Double {
                return Date(timeIntervalSince1970: d)
            }
            if let i = value as? Int {
                return Date(timeIntervalSince1970: Double(i))
            }
            if let s = value as? String {
                if let date = ISO8601DateFormatter().date(from: s) {
                    return date
                }
            }
        }
        return nil
    }
}
