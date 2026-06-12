import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct BodyPreviewView: View {
    @Query(sort: \PeptideProtocol.createdAt, order: .reverse) private var protocols: [PeptideProtocol]

    @State private var sourceImageData: Data?
    @State private var resultImageData: Data?
    @State private var selectedProtocolID = BodyPreviewProtocolOption.trialOptions[0].id
    @State private var confirmedAdultPhoto = false
    @State private var acknowledgedPreview = false
    @State private var isShowingGenerator = false

    private var protocolOptions: [BodyPreviewProtocolOption] {
        let activeOptions = protocols
            .filter { $0.status == .active && PeptideLibrary.isSupportedPeptideName($0.peptideName) }
            .map { BodyPreviewProtocolOption(peptideProtocol: $0) }

        return activeOptions.isEmpty ? BodyPreviewProtocolOption.trialOptions : activeOptions
    }

    private var selectedProtocol: BodyPreviewProtocolOption {
        protocolOptions.first { $0.id == selectedProtocolID } ?? protocolOptions[0]
    }

    private var mainImageData: Data? {
        resultImageData ?? sourceImageData
    }

    private var headline: String {
        if resultImageData != nil {
            "Here's your goal body"
        } else if sourceImageData != nil {
            "Starting point locked in"
        } else {
            "See your Dream Body"
        }
    }

    private var supportingCopy: String {
        if resultImageData != nil {
            "Keep showing up. Small choices compound into visible change."
        } else if sourceImageData != nil {
            "Your photo is ready. Generate a realistic target when you want a little spark."
        } else {
            "Upload a progress photo and create a private wellness visualization."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GoalBodyHeroCard(
                        imageData: mainImageData,
                        headline: headline,
                        supportingCopy: supportingCopy,
                        protocolName: selectedProtocol.title,
                        hasGeneratedPreview: resultImageData != nil
                    )

                    Button {
                        isShowingGenerator = true
                    } label: {
                        Label(
                            mainImageData == nil ? "Upload Photo" : "Create Dream Body",
                            systemImage: mainImageData == nil ? "photo.on.rectangle" : "sparkles"
                        )
                    }
                    .buttonStyle(AuthPrimaryButtonStyle())

                }
                .padding(18)
            }
            .protocolsScreen()
            .navigationTitle("Body Preview")
            .navigationDestination(isPresented: $isShowingGenerator) {
                BodyPreviewGeneratorView(
                    sourceImageData: $sourceImageData,
                    resultImageData: $resultImageData,
                    selectedProtocolID: $selectedProtocolID,
                    confirmedAdultPhoto: $confirmedAdultPhoto,
                    acknowledgedPreview: $acknowledgedPreview,
                    protocolOptions: protocolOptions
                )
            }
        }
    }
}

private struct BodyPreviewGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    @Binding var sourceImageData: Data?
    @Binding var resultImageData: Data?
    @Binding var selectedProtocolID: String
    @Binding var confirmedAdultPhoto: Bool
    @Binding var acknowledgedPreview: Bool

    let protocolOptions: [BodyPreviewProtocolOption]

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isGenerating = false
    @State private var message: String?

    private var selectedProtocol: BodyPreviewProtocolOption {
        protocolOptions.first { $0.id == selectedProtocolID } ?? protocolOptions[0]
    }

    private var canGenerate: Bool {
        sourceImageData != nil
            && confirmedAdultPhoto
            && acknowledgedPreview
            && !isGenerating
            && authManager.client != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    imagePanel
                    protocolPanel
                    consentPanel

                    Button {
                        Task { await generatePreview() }
                    } label: {
                        if isGenerating {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Label("Create Dream Body", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(AuthPrimaryButtonStyle())
                    .disabled(!canGenerate)

                    if let message {
                        AuthMessageView(message: message, style: .warning)
                    }
                }
                .padding(18)
            }
            .protocolsScreen()
            .navigationTitle("Your New Body")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    sourceImageData = try? await newItem?.loadTransferable(type: Data.self)
                    resultImageData = nil
                    message = nil
                }
            }
        }
    }

    private var imagePanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(title: "Photo")

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(sourceImageData == nil ? "Choose Photo" : "Change Photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(AuthSecondaryButtonStyle())

                if sourceImageData != nil || resultImageData != nil {
                    HStack(spacing: 12) {
                        PreviewImageCard(title: "Current", imageData: sourceImageData)

                        PreviewImageCard(title: "Preview", imageData: resultImageData, isLoading: isGenerating)
                    }
                } else {
                    PreviewPhotoPlaceholder()
                }
            }
        }
    }

    private var protocolPanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(title: "Protocol")

                LazyVStack(spacing: 10) {
                    ForEach(protocolOptions) { option in
                        BodyPreviewProtocolOptionRow(
                            option: option,
                            isSelected: selectedProtocol.id == option.id
                        ) {
                            selectedProtocolID = option.id
                            resultImageData = nil
                            message = nil
                        }
                    }
                }
            }
        }
    }

    private var consentPanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 12) {
                Label("Illustrative only", systemImage: "exclamationmark.shield.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                Text("Generated previews are not medical advice, not a promise of medication results, and should not be used to judge health status.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Photo is an adult, non-explicit image", isOn: $confirmedAdultPhoto)
                    .font(.subheadline.weight(.semibold))

                Toggle("I understand this is only a visual simulation", isOn: $acknowledgedPreview)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func generatePreview() async {
        guard let sourceImageData else { return }

        isGenerating = true
        message = nil
        resultImageData = nil

        do {
            let service = BodyPreviewService(client: authManager.client)
            resultImageData = try await service.generatePreview(
                imageData: sourceImageData,
                protocolName: selectedProtocol.promptProtocolName
            )
            dismiss()
        } catch {
            message = friendlyMessage(for: error)
        }

        isGenerating = false
    }

    private func friendlyMessage(for error: Error) -> String {
        if let bodyPreviewError = error as? BodyPreviewError,
           let description = bodyPreviewError.errorDescription {
            return description
        }

        return error.localizedDescription.isEmpty
            ? "Unable to generate that preview. Try again with a different photo."
            : error.localizedDescription
    }
}

private struct BodyPreviewProtocolOption: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let badge: String
    let promptProtocolName: String
    let isTrial: Bool

    init(peptideProtocol: PeptideProtocol) {
        id = "protocol-\(peptideProtocol.id.uuidString)"
        title = peptideProtocol.name
        subtitle = peptideProtocol.peptideName
        detail = "Phase \(peptideProtocol.phaseIndex() + 1) | \(peptideProtocol.formattedCurrentDose) | every \(peptideProtocol.repeatIntervalDays)d"
        badge = "Active"
        promptProtocolName = peptideProtocol.peptideName
        isTrial = false
    }

    private init(
        id: String,
        title: String,
        subtitle: String,
        detail: String,
        promptProtocolName: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.badge = "Trial"
        self.promptProtocolName = promptProtocolName
        self.isTrial = true
    }

    static let trialOptions = [
        BodyPreviewProtocolOption(
            id: "trial-retatrutide",
            title: "Trial Retatrutide Protocol",
            subtitle: "Hypothetical GLP / GIP / glucagon preview",
            detail: "Trial protocol",
            promptProtocolName: "Retatrutide"
        ),
        BodyPreviewProtocolOption(
            id: "trial-ozempic",
            title: "Trial Ozempic Protocol",
            subtitle: "Hypothetical semaglutide GLP-1 preview",
            detail: "Trial protocol",
            promptProtocolName: "Semaglutide / Ozempic"
        ),
        BodyPreviewProtocolOption(
            id: "trial-glp-1",
            title: "Trial GLP-1 Protocol",
            subtitle: "Hypothetical GLP-1 preview",
            detail: "Trial protocol",
            promptProtocolName: "GLP-1"
        )
    ]
}

private struct BodyPreviewProtocolOptionRow: View {
    let option: BodyPreviewProtocolOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? AppTheme.accent.opacity(0.2) : AppTheme.elevatedStrong)

                    Image(systemName: option.isTrial ? "sparkles" : "square.stack.3d.up.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(option.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(option.badge.uppercased())
                            .font(.caption2.weight(.black))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(AppTheme.accent.opacity(0.18), in: Capsule())
                            .foregroundStyle(AppTheme.accent)
                    }

                    Text(option.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)

                    Text(option.detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textSecondary)
            }
            .padding(12)
            .background(isSelected ? AppTheme.accent.opacity(0.1) : AppTheme.elevatedStrong)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.6) : AppTheme.divider)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct GoalBodyHeroCard: View {
    let imageData: Data?
    let headline: String
    let supportingCopy: String
    let protocolName: String
    let hasGeneratedPreview: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.largeTitle.weight(.black))
                    .fixedSize(horizontal: false, vertical: true)

                Text(supportingCopy)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.elevatedStrong)

                if let imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(AppTheme.accent)

                        Text("No goal image yet")
                            .font(.headline.weight(.semibold))

                        Text("Start with a clear adult progress photo.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                LinearGradient(
                    colors: [.clear, AppTheme.background.opacity(0.88)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(spacing: 8) {
                    Label(hasGeneratedPreview ? "Goal" : "Current", systemImage: hasGeneratedPreview ? "sparkles" : "camera.fill")
                        .font(.caption.weight(.bold))

                    Text(protocolName)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.black.opacity(0.58), in: Capsule())
                .foregroundStyle(.white)
                .padding(14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 500)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.divider)
            }
        }
    }
}

private struct PreviewImageCard: View {
    let title: String
    let imageData: Data?
    var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.elevatedStrong)

                if isLoading {
                    ProgressView()
                        .tint(AppTheme.accent)
                } else if let imageData,
                          let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(height: 230)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.divider)
            }
        }
    }
}

private struct PreviewPhotoPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "photo")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            Text("No photo selected")
                .font(.headline.weight(.semibold))

            Text("Select a clear, shirtless photo to see what you'll look like.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.elevatedStrong)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
