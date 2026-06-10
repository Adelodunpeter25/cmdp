import SwiftUI

struct SettingsView: View {
    @ObservedObject var searchService: SearchService
    @StateObject private var launchService = LaunchAtLoginService.shared
    @Binding var isSettingsMode: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SETTINGS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Button(action: {
                    isSettingsMode = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider().opacity(0.3)
            
            VStack(spacing: 16) {
                // Launch at Login
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Open at Login")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Text("Automatically start cmdp when you log in.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary.opacity(0.8))
                    }
                    Spacer()
                    Toggle("", isOn: $launchService.isEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.hoverBackground.opacity(0.5))
                .cornerRadius(8)
                
                // Index Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Software")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 8)

                    Button(action: {
                        AppDelegate.shared?.updaterController?.checkForUpdates(nil)
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.circle")
                                .font(.system(size: 12))
                            Text("Check for Updates...")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("Index Management")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 8)
                    
                    Button(action: {
                        searchService.resetIndex()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                            Text("Rebuild Search Index")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
            
            Spacer()
            
            Divider().opacity(0.3)
            
            HStack {
                Text("cmdp v1.0.0")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
                Spacer()
                Text("Esc to close")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(height: 300)
    }
}
