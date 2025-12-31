import Foundation
import Observation
import CryptoKit

// MARK: - Last.fm Scrobbling Service

/// Service for interacting with the Last.fm API.
/// Handles authentication, now playing updates, and scrobbling.
@available(macOS 26.0, *)
@MainActor
@Observable
final class LastFmService {
    private let logger = DiagnosticsLogger.scrobble
    private let baseURL = URL(string: "https://ws.audioscrobbler.com/2.0/")!
    
    /// Current authentication state.
    enum AuthState {
        case loggedOut
        case authenticating
        case loggedIn(username: String)
        case error(String)
    }
    
    var authState: AuthState = .loggedOut
    
    init() {
        if let username = SettingsManager.shared.lastFmUsername,
           SettingsManager.shared.lastFmSessionKey != nil {
            self.authState = .loggedIn(username: username)
        }
    }
    
    // MARK: - Authentication
    
    /// Generates the authorization URL for the user to login.
    func getAuthorizationURL() -> URL? {
        let apiKey = SettingsManager.shared.lastFmApiKey
        guard !apiKey.isEmpty else { return nil }
        
        // Using callback kaset://lastfm-auth to handle redirection
        return URL(string: "https://www.last.fm/api/auth/?api_key=\(apiKey)&cb=kaset://lastfm-auth")
    }
    
    /// Fetches a session key using the token received from the callback.
    func handleAuthToken(_ token: String) async {
        self.authState = .authenticating
        
        let apiKey = SettingsManager.shared.lastFmApiKey
        let sharedSecret = SettingsManager.shared.lastFmSharedSecret
        
        guard !apiKey.isEmpty, !sharedSecret.isEmpty else {
            self.authState = .error("API Key or Shared Secret missing")
            return
        }
        
        var params: [String: String] = [
            "method": "auth.getSession",
            "api_key": apiKey,
            "token": token
        ]
        
        params["api_sig"] = self.generateSignature(params: params, secret: sharedSecret)
        params["format"] = "json"
        
        do {
            let data = try await self.performRequest(params: params)
            let response = try JSONDecoder().decode(LastFmSessionResponse.self, from: data)
            
            SettingsManager.shared.lastFmSessionKey = response.session.key
            SettingsManager.shared.lastFmUsername = response.session.name
            SettingsManager.shared.isLastFmScrobblingEnabled = true
            
            self.authState = .loggedIn(username: response.session.name)
            self.logger.info("Successfully logged in to Last.fm as \(response.session.name)")
        } catch {
            self.logger.error("Failed to get Last.fm session: \(error.localizedDescription)")
            self.authState = .error("Failed to authenticate with Last.fm")
        }
    }
    
    func signOut() {
        SettingsManager.shared.lastFmSessionKey = nil
        SettingsManager.shared.lastFmUsername = nil
        self.authState = .loggedOut
    }
    
    // MARK: - Scrobbling Actions
    
    /// Updates the "Now Playing" status on Last.fm.
    func updateNowPlaying(artist: String, track: String, album: String?) async {
        guard SettingsManager.shared.isLastFmScrobblingEnabled,
              let sessionKey = SettingsManager.shared.lastFmSessionKey else { return }
        
        let apiKey = SettingsManager.shared.lastFmApiKey
        let sharedSecret = SettingsManager.shared.lastFmSharedSecret
        
        var params: [String: String] = [
            "method": "track.updateNowPlaying",
            "artist": artist,
            "track": track,
            "api_key": apiKey,
            "sk": sessionKey
        ]
        
        if let album = album {
            params["album"] = album
        }
        
        params["api_sig"] = self.generateSignature(params: params, secret: sharedSecret)
        params["format"] = "json"
        
        do {
            _ = try await self.performRequest(params: params)
            self.logger.info("Updated Last.fm Now Playing: \(artist) - \(track)")
        } catch {
            self.logger.error("Failed to update Last.fm Now Playing: \(error.localizedDescription)")
        }
    }
    
    /// Scrobbles a track to Last.fm.
    func scrobble(artist: String, track: String, album: String?, timestamp: Int) async {
        guard SettingsManager.shared.isLastFmScrobblingEnabled,
              let sessionKey = SettingsManager.shared.lastFmSessionKey else { return }
        
        let apiKey = SettingsManager.shared.lastFmApiKey
        let sharedSecret = SettingsManager.shared.lastFmSharedSecret
        
        var params: [String: String] = [
            "method": "track.scrobble",
            "artist": artist,
            "track": track,
            "timestamp": String(timestamp),
            "api_key": apiKey,
            "sk": sessionKey
        ]
        
        if let album = album {
            params["album"] = album
        }
        
        params["api_sig"] = self.generateSignature(params: params, secret: sharedSecret)
        params["format"] = "json"
        
        do {
            _ = try await self.performRequest(params: params)
            self.logger.info("Successfully scrobbled to Last.fm: \(artist) - \(track)")
        } catch {
            self.logger.error("Failed to scrobble to Last.fm: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateSignature(params: [String: String], secret: String) -> String {
        // 1. Sort parameters alphabetically by key.
        let sortedKeys = params.keys.sorted()
        
        // 2. Concatenate keys and values.
        var signatureString = ""
        for key in sortedKeys {
            signatureString += key + (params[key] ?? "")
        }
        
        // 3. Append the shared secret.
        signatureString += secret
        
        // 4. Return MD5 hash.
        return self.md5(signatureString)
    }
    
    private func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: string.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    private func performRequest(params: [String: String]) async throws -> Data {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = params.compactMap { (key, value) -> String? in
            guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryNameValueAllowed),
                  let encodedValue = value.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryNameValueAllowed) else {
                return nil
            }
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        request.httpBody = bodyString.data(using: String.Encoding.utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "LastFmService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            self.logger.error("Last.fm API returned error \(httpResponse.statusCode): \(errorMsg)")
            throw NSError(domain: "LastFmService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(httpResponse.statusCode)"])
        }
        
        return data
    }
}

// MARK: - CharacterSet Extension

extension CharacterSet {
    /// Character set for URL query names and values in application/x-www-form-urlencoded.
    static let urlQueryNameValueAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&=+")
        return cs
    }()
}

// MARK: - Last.fm Models

struct LastFmSessionResponse: Codable {
    let session: LastFmSession
}

struct LastFmSession: Codable {
    let name: String
    let key: String
}
