import SwiftUI

struct PeptideLibraryView: View {
    @AppStorage("preferredPeptideName") private var preferredPeptideName = PeptideLibrary.peptideNames.first ?? "Semaglutide"
    @State private var searchText = ""

    private var filteredItems: [PeptideInfo] {
        let orderedItems = PeptideLibrary.orderedItems(preferredPeptideName: preferredPeptideName)

        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return orderedItems
        }

        return orderedItems.filter { item in
            let haystack = "\(item.name) \(item.aliases) \(item.category) \(item.summary)".lowercased()
            return haystack.contains(searchText.lowercased())
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // DisclaimerBanner(compact: true)

                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems) { item in
                            NavigationLink(value: item) {
                                PeptideCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
            }
            .protocolsScreen()
            .navigationTitle("Library")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationDestination(for: PeptideInfo.self) { item in
                PeptideDetailView(item: item)
            }
        }
    }
}

private struct PeptideCard: View {
    let item: PeptideInfo

    var body: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.title3.weight(.black))

                        Text(item.aliases)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text(item.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                    LibraryChip(title: item.category, systemImage: "hexagon")
                    LibraryChip(title: item.cadence, systemImage: "calendar")
                }
            }
        }
    }
}

private struct LibraryChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppTheme.elevatedStrong)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(AppTheme.textSecondary)
    }
}

private struct PeptideDetailView: View {
    let item: PeptideInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AppPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.name)
                            .font(.largeTitle.weight(.black))

                        Text(item.aliases)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)

                        Text(item.summary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                LibrarySection(title: "Overview", bodyText: item.overview, icon: "doc.text")
                LibrarySection(title: "Mechanism", bodyText: item.mechanism, icon: "bolt.horizontal")
                LibrarySection(title: "Common Dosing Protocols", bodyText: item.dosingProtocols, icon: "list.bullet.clipboard")
                LibrarySection(title: "Reconstitution", bodyText: item.reconstitution, icon: "drop")
                LibrarySection(title: "Storage", bodyText: item.storage, icon: "snowflake")
                DisclaimerBanner()
            }
            .padding(18)
        }
        .protocolsScreen()
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LibrarySection: View {
    let title: String
    let bodyText: String
    let icon: String

    var body: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                Text(bodyText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
