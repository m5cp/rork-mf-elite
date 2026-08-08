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

    /// Delete rows and report how many actually went.
    ///
    /// `delete` can only tell you the request was accepted. PostgREST answers a
    /// DELETE that an RLS policy filtered down to nothing with 204 No Content —
    /// indistinguishable from a real delete — so "not allowed" reads as
    /// success. Asking for the deleted rows back makes the difference visible.
    /// Returns nil when the request itself failed.
    func deleteCounting(table: String, match: [String: String]) async -> Int? {
        let query = match.map { URLQueryItem(name: $0.key, value: "eq.\($0.value)") }
        guard var request = await makeRequest(table: table, method: "DELETE", query: query) else { return nil }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        guard let (data, http) = await send(request) else { return nil }
        guard (200..<300).contains(http.statusCode) else {
            print("[SupabaseClient] DELETE \(table) failed: HTTP \(http.statusCode)")
            return nil
        }
        let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        return rows?.count ?? 0
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

    // MARK: - Storage

    /// Upload a file to a storage bucket. Overwrites any existing object at path.
    /// POST {base}/storage/v1/object/{bucket}/{path} with x-upsert: true.
    func uploadStorage(bucket: String, path: String, data: Data, contentType: String) async -> Bool {
        guard var request = await makeStorageRequest(bucket: bucket, path: path, method: "POST") else { return false }
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data
        guard let (_, response) = await send(request) else { return false }
        return (200...299).contains(response.statusCode)
    }

    /// Public URL for an object in a PUBLIC bucket (no auth needed to read).
    func publicStorageURL(bucket: String, path: String) -> String {
        "\(SupabaseConfig.url)/storage/v1/object/public/\(bucket)/\(path)"
    }

    private func makeStorageRequest(bucket: String, path: String, method: String) async -> URLRequest? {
        guard let url = URL(string: "\(SupabaseConfig.url)/storage/v1/object/\(bucket)/\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 120
        await applyAuthHeaders(to: &request)
        return request
    }

    // MARK: - Plumbing

    private func makeRequest(table: String, method: String, query: [URLQueryItem]) async -> URLRequest? {
        guard var components = URLComponents(string: "\(SupabaseConfig.url)/rest/v1/\(table)") else { return nil }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        await applyAuthHeaders(to: &request)
        return request
    }

    /// Attach the anon apikey and, when signed in, the bearer access token —
    /// the exact auth headers every authenticated request carries.
    private func applyAuthHeaders(to request: inout URLRequest) async {
        request.setValue(SupabaseConfig.apiKey, forHTTPHeaderField: "apikey")
        if let token = await SupabaseAuth.shared.validAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    /// Outcome of a mutation, distinguishing errors that will never succeed on
    /// retry (4xx: bad column, missing table, RLS denial) from transient ones
    /// (network drop, 5xx). Permanent failures must be quarantined by callers,
    /// never retried forever.
    enum MutationOutcome {
        case success
        case transientFailure
        case permanentFailure(status: Int)

        var isSuccess: Bool { if case .success = self { return true }; return false }
    }

    private func mutate(_ request: URLRequest, label: String) async -> Bool {
        await mutateOutcome(request, label: label).isSuccess
    }

    private func mutateOutcome(_ request: URLRequest, label: String) async -> MutationOutcome {
        guard let (_, http) = await send(request) else { return .transientFailure }
        if (200..<300).contains(http.statusCode) { return .success }
        print("[SupabaseClient] \(label) failed: HTTP \(http.statusCode)")
        // 408 (timeout) and 429 (rate limit) are retryable; other 4xx are not.
        if (400..<500).contains(http.statusCode), http.statusCode != 408, http.statusCode != 429 {
            return .permanentFailure(status: http.statusCode)
        }
        return .transientFailure
    }

    /// Upsert returning a classified outcome (used by the sync outbox).
    func upsertOutcome(table: String, values: [String: Any], onConflict: String? = nil) async -> MutationOutcome {
        var query: [URLQueryItem] = []
        if let onConflict { query.append(URLQueryItem(name: "on_conflict", value: onConflict)) }
        guard var request = await makeRequest(table: table, method: "POST", query: query) else { return .transientFailure }
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: values)
        return await mutateOutcome(request, label: "UPSERT \(table)")
    }

    /// Delete returning a classified outcome (used by the sync outbox).
    func deleteOutcome(table: String, match: [String: String]) async -> MutationOutcome {
        let query = match.map { URLQueryItem(name: $0.key, value: "eq.\($0.value)") }
        guard let request = await makeRequest(table: table, method: "DELETE", query: query) else { return .transientFailure }
        return await mutateOutcome(request, label: "DELETE \(table)")
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
