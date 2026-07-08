//
//  SupabaseClient.swift
//  MFElite
//
//  A thin PostgREST wrapper over URLSession. Every request carries the apikey
//  header and, when signed in, an Authorization: Bearer token. All methods fail
//  soft — they log and return a neutral result, never throwing into the UI.
//

import Foundation

@MainActor
final class SupabaseClient {
    static let shared = SupabaseClient()

    private init() {}

    // MARK: - Public API

    /// Fetch rows from a table. Returns decoded JSON objects, or nil on failure.
    @discardableResult
    func get(table: String, query: [URLQueryItem] = []) async -> [[String: Any]]? {
        guard let request = await makeRequest(table: table, method: "GET", query: query) else { return nil }
        guard let (data, http) = await send(request) else { return nil }
        guard (200..<300).contains(http.statusCode) else {
            print("[SupabaseClient] GET \(table) failed: HTTP \(http.statusCode)")
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
    }

    /// Insert a single row. Returns true on success.
    @discardableResult
    func insert(table: String, values: [String: Any]) async -> Bool {
        guard var request = await makeRequest(table: table, method: "POST", query: []) else { return false }
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: values)
        return await mutate(request, label: "INSERT \(table)")
    }

    /// Upsert a single row, merging on `onConflict` columns when provided.
    @discardableResult
    func upsert(table: String, values: [String: Any], onConflict: String? = nil) async -> Bool {
        var query: [URLQueryItem] = []
        if let onConflict { query.append(URLQueryItem(name: "on_conflict", value: onConflict)) }
        guard var request = await makeRequest(table: table, method: "POST", query: query) else { return false }
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: values)
        return await mutate(request, label: "UPSERT \(table)")
    }

    /// Update rows matching the given query filters with the provided values.
    @discardableResult
    func update(table: String, values: [String: Any], match: [URLQueryItem]) async -> Bool {
        guard var request = await makeRequest(table: table, method: "PATCH", query: match) else { return false }
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: values)
        return await mutate(request, label: "UPDATE \(table)")
    }

    /// Delete rows matching the given equality filters.
    @discardableResult
    func delete(table: String, match: [String: String]) async -> Bool {
        let query = match.map { URLQueryItem(name: $0.key, value: "eq.\($0.value)") }
        guard let request = await makeRequest(table: table, method: "DELETE", query: query) else { return false }
        return await mutate(request, label: "DELETE \(table)")
    }

    /// Call a Postgres function (RPC). Returns true on success. Used for
    /// privileged server-side operations a client cannot do directly (e.g. a
    /// SECURITY DEFINER `delete_account` that removes the auth user). Safe no-op
    /// (logs and returns false) when the function is not installed.
    @discardableResult
    func rpc(_ function: String, params: [String: Any] = [:]) async -> Bool {
        guard var request = await makeRequest(table: "rpc/\(function)", method: "POST", query: []) else { return false }
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: params)
        return await mutate(request, label: "RPC \(function)")
    }

    /// Call a Postgres function (RPC) and return its raw JSON response body.
    /// Returns nil on transport/HTTP failure (offline, 401 after retry, 5xx) so
    /// callers can distinguish that from a successful call returning JSON `null`.
    func rpcData(_ function: String, params: [String: Any] = [:]) async -> Data? {
        guard var request = await makeRequest(table: "rpc/\(function)", method: "POST", query: []) else { return nil }
        request.httpBody = try? JSONSerialization.data(withJSONObject: params)
        guard let (data, http) = await send(request) else { return nil }
        guard (200..<300).contains(http.statusCode) else {
            print("[SupabaseClient] RPC \(function) failed: HTTP \(http.statusCode)")
            return nil
        }
        return data
    }

    // MARK: - Plumbing

    private func makeRequest(table: String, method: String, query: [URLQueryItem]) async -> URLRequest? {
        guard var components = URLComponents(string: "\(SupabaseConfig.url)/rest/v1/\(table)") else { return nil }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await SupabaseAuth.shared.validAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func mutate(_ request: URLRequest, label: String) async -> Bool {
        guard let (_, http) = await send(request) else { return false }
        guard (200..<300).contains(http.statusCode) else {
            print("[SupabaseClient] \(label) failed: HTTP \(http.statusCode)")
            return false
        }
        return true
    }

    /// Perform a request, transparently refreshing once on a 401.
    private func send(_ request: URLRequest, allowRetry: Bool = true) async -> (Data, HTTPURLResponse)? {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            if http.statusCode == 401, allowRetry, let token = await SupabaseAuth.shared.forceRefresh() {
                var retry = request
                retry.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                return await send(retry, allowRetry: false)
            }
            return (data, http)
        } catch {
            print("[SupabaseClient] Network error: \(error.localizedDescription)")
            return nil
        }
    }
}
