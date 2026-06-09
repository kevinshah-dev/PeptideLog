import SwiftUI

struct AppRootView: View {
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.dark.rawValue
    @StateObject private var authManager = AuthManager()
    @State private var showingSettings = false

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceMode) ?? .dark
    }

    var body: some View {
        Group {
            switch authManager.phase {
            case .checking:
                LoadingAuthView()
            case .unauthenticated:
                AuthRootView()
            case .onboarding:
                OnboardingView()
            case .authenticated:
                MainTabView {
                    showingSettings = true
                }
            }
        }
        .environmentObject(authManager)
        .tint(AppTheme.accent)
        .preferredColorScheme(selectedAppearance.colorScheme)
        .onOpenURL { url in
            authManager.handleOpenURL(url)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(authManager)
                .preferredColorScheme(selectedAppearance.colorScheme)
        }
    }
}

private struct MainTabView: View {
    let openSettings: () -> Void

    var body: some View {
        TabView {
            ProtocolsDashboardView(openSettings: openSettings)
                .tabItem {
                    Label("Protocols", systemImage: "square.stack.3d.up")
                }

            PeptideLibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }

        }
        .toolbarBackground(AppTheme.elevated, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

private struct LoadingAuthView: View {
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                BrandMark()

                ProgressView()
                    .tint(AppTheme.accent)

                Text("Securing session")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.dark.rawValue
    @State private var logoutMessage: String?
    @State private var isLoggingOut = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AppPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Appearance")
                                .font(.headline.weight(.semibold))

                            Picker("Appearance", selection: $appearanceMode) {
                                ForEach(AppAppearance.allCases) { mode in
                                    Text(mode.rawValue).tag(mode.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    DisclaimerBanner()

                    AppPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Account")
                                .font(.headline.weight(.semibold))

                            Text(authManager.currentUserLabel)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Button(role: .destructive) {
                                Task { await logout() }
                            } label: {
                                if isLoggingOut {
                                    ProgressView()
                                        .tint(AppTheme.danger)
                                } else {
                                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoggingOut)

                            if let logoutMessage {
                                Text(logoutMessage)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.warning)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(18)
            }
            .protocolsScreen()
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func logout() async {
        isLoggingOut = true
        logoutMessage = nil
        let result = await authManager.signOut()
        isLoggingOut = false

        if result.isSuccess {
            dismiss()
        } else {
            logoutMessage = result.message
        }
    }
}
