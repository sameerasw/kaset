import SwiftUI

// MARK: - Scrobbling Settings View

@available(macOS 26.0, *)
struct ScrobblingSettingsView: View {
    @Environment(PlayerService.self) private var playerService
    @State private var settings = SettingsManager.shared
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last.fm API Configuration")
                        .font(.headline)
                    
                    Text("To enable scrobbling, you need to provide your own Last.fm API Key and Shared Secret. You can get these from the [Last.fm API accounts page](https://www.last.fm/api/account/create).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
                
                TextField("API Key", text: self.$settings.lastFmApiKey)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("Shared Secret", text: self.$settings.lastFmSharedSecret)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Last.fm Credentials")
            }
            
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Status")
                            .font(.headline)
                        
                        switch self.playerService.lastFmService.authState {
                        case .loggedOut:
                            Text("Not authenticated")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        case .authenticating:
                            Text("Authenticating...")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        case .loggedIn(let username):
                            Text("Logged in as \(username)")
                                .font(.caption)
                                .foregroundStyle(.green)
                        case .error(let message):
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Spacer()
                    
                    if case .loggedIn = self.playerService.lastFmService.authState {
                        Button("Sign Out") {
                            self.playerService.lastFmService.signOut()
                        }
                    } else {
                        Button("Login with Last.fm") {
                            if let url = self.playerService.lastFmService.getAuthorizationURL() {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .disabled(self.settings.lastFmApiKey.isEmpty || self.settings.lastFmSharedSecret.isEmpty)
                    }
                }
                .padding(.vertical, 4)
                
                if case .loggedIn = self.playerService.lastFmService.authState {
                    Toggle("Enable Scrobbling", isOn: self.$settings.isLastFmScrobblingEnabled)
                }
            } header: {
                Text("Account")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Scrobbling")
    }
}
