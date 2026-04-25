import Foundation

// MARK: - AuthManager
// Handles login state, token storage, and session management.
// Token is persisted in UserDefaults so login survives app restarts.

class AuthManager {
    static let shared = AuthManager()
    private init() {}

    // ⚠️ Replace with your server's address
    // Example: "http://192.168.1.100:3000"
    // Example: "https://yourdomain.com"
    let serverURL = "http://embtech.llc:3030"

    private let tokenKey    = "ems_auth_token"
    private let usernameKey = "ems_username"

    // MARK: - State

    var isLoggedIn: Bool {
        return token != nil
    }

    var token: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }

    var username: String? {
        get { UserDefaults.standard.string(forKey: usernameKey) }
        set { UserDefaults.standard.set(newValue, forKey: usernameKey) }
    }

    // MARK: - Login

    func login(
        username: String,
        password: String,
        completion: @escaping (Result<Void, AuthError>) -> Void
    ) {
        guard let url = URL(string: "\(serverURL)/auth/login") else {
            completion(.failure(.invalidURL))
            return
        }

        var request        = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody   = try? JSONSerialization.data(withJSONObject: [
            "username": username,
            "password": password
        ])

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error.localizedDescription)))
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    completion(.failure(.invalidResponse))
                    return
                }

                if let token = json["token"] as? String {
                    self.token    = token
                    self.username = username
                    completion(.success(()))
                } else if let message = json["error"] as? String {
                    completion(.failure(.serverError(message)))
                } else {
                    completion(.failure(.invalidCredentials))
                }
            }
        }.resume()
    }

    // MARK: - Logout

    func logout(completion: (() -> Void)? = nil) {
        guard let token = token,
              let url   = URL(string: "\(serverURL)/auth/logout") else {
            clearSession()
            completion?()
            return
        }

        var request        = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async {
                self.clearSession()
                completion?()
            }
        }.resume()
    }

    // MARK: - Validate Token (check if still valid on app launch)

    func validateToken(completion: @escaping (Bool) -> Void) {
        guard let token = token,
              let url   = URL(string: "\(serverURL)/auth/validate") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    completion(true)
                } else {
                    // Token invalid or expired — clear it
                    self.clearSession()
                    completion(false)
                }
            }
        }.resume()
    }

    // MARK: - Force Logout (called when server kicks a user)

    func forceLogout() {
        clearSession()
        // Post notification so the app can react and show login screen
        NotificationCenter.default.post(name: .userForcedLogout, object: nil)
    }

    // MARK: - Private

    private func clearSession() {
        token    = nil
        username = nil
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case invalidURL
    case networkError(String)
    case invalidResponse
    case invalidCredentials
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "Invalid server URL"
        case .networkError(let msg):   return "Network error: \(msg)"
        case .invalidResponse:         return "Invalid server response"
        case .invalidCredentials:      return "Incorrect username or password"
        case .serverError(let msg):    return msg
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userForcedLogout = Notification.Name("EMSUserForcedLogout")
}
