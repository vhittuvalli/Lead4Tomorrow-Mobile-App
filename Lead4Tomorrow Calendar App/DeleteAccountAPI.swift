import Foundation

/// Tries several common patterns and returns server detail text.
@discardableResult
func performDelete(email: String) async -> (ok: Bool, detail: String) {
    guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return (false, "No email provided to delete.")
    }
    guard let base = URL(string: APIConfig.baseURL) else {
        return (false, "Bad base URL.")
    }

    func send(_ req: URLRequest) async -> (ok: Bool, detail: String) {
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? ""
            if status == 200 { return (true, "OK") }
            return (false, "HTTP \(status): \(text)")
        } catch {
            return (false, "Network error: \(error.localizedDescription)")
        }
    }
    func jsonReq(_ url: URL, method: String, payload: [String: String]) -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONEncoder().encode(payload)
        return r
    }
    func formReq(_ url: URL, method: String, fields: [String: String]) -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = fields.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                         .joined(separator: "&")
        r.httpBody = body.data(using: .utf8)
        return r
    }

    // 1) POST JSON to /delete_profile (your Flask route we added)
    var url = base.appendingPathComponent("delete_profile")
    var result = await send(jsonReq(url, method: "POST", payload: ["email": email]))
    if result.ok { return result }

    // 2) DELETE with query param (for servers that ignore DELETE bodies)
    if var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
        comps.queryItems = [URLQueryItem(name: "email", value: email)]
        if let qurl = comps.url {
            var r = URLRequest(url: qurl)
            r.httpMethod = "DELETE"
            result = await send(r)
            if result.ok { return result }
        }
    }

    // 3) Alternate route name
    url = base.appendingPathComponent("delete_account")
    result = await send(jsonReq(url, method: "POST", payload: ["email": email]))
    if result.ok { return result }

    // 4) Form-encoded POST to /delete_profile
    url = base.appendingPathComponent("delete_profile")
    result = await send(formReq(url, method: "POST", fields: ["email": email]))
    if result.ok { return result }

    return result // last error details
}

