import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var step = 0
    @State private var selectedPeptideName: String

    init() {
        let defaultPeptide = PeptideLibrary.supportedPeptideName(
            UserDefaults.standard.string(forKey: "preferredPeptideName")
        )
        _selectedPeptideName = State(initialValue: defaultPeptide)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch step {
                    case 0:
                        welcomeStep
                    case 1:
                        disclaimerStep
                    default:
                        setupStep
                    }
                }

                OnboardingProgress(step: step)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
            }
        }
        .tint(AppTheme.accent)
    }

    private var welcomeStep: some View {
        OnboardingScreen {
            VStack(alignment: .leading, spacing: 22) {
                BrandMark()
                    .scaleEffect(1.25, anchor: .leading)
                    .frame(width: 76, height: 76, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to Protocols")
                        .font(.largeTitle.weight(.black))

                    Text("A polished companion for keeping your GLP protocol organized.")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AppPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureLine(icon: "syringe", text: "Dose logging tracks amount, timing, site, and reminders.")
                        FeatureLine(icon: "chart.line.uptrend.xyaxis", text: "Titration timelines show your current phase and next step.")
                        FeatureLine(icon: "waveform.path.ecg", text: "Side-effect history keeps severity and notes in context.")
                        FeatureLine(icon: "figure", text: "Progress tools chart weight, measurements, and photos.")
                    }
                }

                Button {
                    withAnimation(.snappy) { step = 1 }
                } label: {
                    Label("Continue", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(AuthPrimaryButtonStyle())
            }
        }
    }

    private var disclaimerStep: some View {
        OnboardingScreen {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Medical Disclaimer")
                        .font(.largeTitle.weight(.black))

                    Text("Please confirm before using Protocols.")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                DisclaimerBanner()

                Button {
                    withAnimation(.snappy) { step = 2 }
                } label: {
                    Label("I Understand", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(AuthPrimaryButtonStyle())
            }
        }
    }

    private var setupStep: some View {
        OnboardingScreen {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Setup")
                        .font(.largeTitle.weight(.black))

                    Text("Choose the medication or GLP protocol you are currently using so Protocols can surface it first.")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AppPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Current Protocol")
                            .font(.headline.weight(.semibold))

                        Picker("Current protocol", selection: $selectedPeptideName) {
                            ForEach(PeptideLibrary.peptideNames, id: \.self) { peptideName in
                                Text(peptideName).tag(peptideName)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 170)
                    }
                }

                Button {
                    authManager.completeOnboarding(preferredPeptideName: selectedPeptideName)
                } label: {
                    Label("Enter Protocols", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(AuthPrimaryButtonStyle())
            }
        }
    }
}

private struct OnboardingScreen<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Spacer(minLength: 24)
                content
                Spacer(minLength: 24)
            }
            .padding(24)
        }
    }
}

private struct FeatureLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingProgress: View {
    let step: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == step ? AppTheme.accent : AppTheme.divider)
                    .frame(height: 5)
            }
        }
        .accessibilityLabel("Onboarding step \(step + 1) of 3")
    }
}
