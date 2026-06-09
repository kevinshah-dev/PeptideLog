import SwiftData
import SwiftUI

private enum EffectWindow: String, CaseIterable, Identifiable {
    case all = "All"
    case thirty = "30D"
    case ninety = "90D"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .all: nil
        case .thirty: 30
        case .ninety: 90
        }
    }
}

struct SideEffectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SideEffectEntry.date, order: .reverse) private var entries: [SideEffectEntry]

    @State private var showingEntrySheet = false
    @State private var searchText = ""
    @State private var selectedWindow = EffectWindow.all
    @State private var minimumSeverity = 1

    private var filteredEntries: [SideEffectEntry] {
        entries.filter { entry in
            let dateMatches: Bool
            if let days = selectedWindow.days,
               let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) {
                dateMatches = entry.date >= cutoff
            } else {
                dateMatches = true
            }

            let textMatches: Bool
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                textMatches = true
            } else {
                let haystack = "\(entry.symptom) \(entry.notes)".lowercased()
                textMatches = haystack.contains(searchText.lowercased())
            }

            return dateMatches && textMatches && entry.severity >= minimumSeverity
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    filterPanel

                    SectionHeading(
                        title: "Timeline",
                        actionTitle: "Log",
                        systemImage: "plus.circle.fill",
                        action: { showingEntrySheet = true }
                    )

                    if filteredEntries.isEmpty {
                        EmptyStateView(
                            title: "No matching effects",
                            subtitle: "Side-effect entries appear here with severity and notes.",
                            systemImage: "waveform.path.ecg"
                        )
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredEntries, id: \.id) { entry in
                                SideEffectRow(entry: entry)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            modelContext.delete(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(18)
            }
            .protocolsScreen()
            .navigationTitle("Effects")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEntrySheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Log side effect")
                }
            }
            .sheet(isPresented: $showingEntrySheet) {
                SideEffectEntrySheet()
            }
        }
    }

    private var filterPanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Filters")
                        .font(.headline.weight(.semibold))

                    Spacer()

                    SeverityDots(severity: minimumSeverity)
                }

                Picker("Window", selection: $selectedWindow) {
                    ForEach(EffectWindow.allCases) { window in
                        Text(window.rawValue).tag(window)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(
                    "Minimum severity \(minimumSeverity)",
                    value: $minimumSeverity,
                    in: 1...5
                )
                .font(.subheadline.weight(.medium))
            }
        }
    }
}

private struct SideEffectRow: View {
    let entry: SideEffectEntry

    var body: some View {
        AppPanel(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.symptom)
                            .font(.headline.weight(.bold))

                        Text(entry.date.formatted(.dateTime.month().day().year().hour().minute()))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    SeverityDots(severity: entry.severity)
                }

                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct SideEffectEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date()
    @State private var symptom = ""
    @State private var severity = 3
    @State private var notes = ""

    private let commonSymptoms = [
        "Nausea",
        "Constipation",
        "Fatigue",
        "Headache",
        "Injection site reaction",
        "Heartburn"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $date)

                    TextField("Symptom", text: $symptom)

                    Picker("Common", selection: $symptom) {
                        Text("Custom").tag("")
                        ForEach(commonSymptoms, id: \.self) { symptom in
                            Text(symptom).tag(symptom)
                        }
                    }
                }

                Section("Severity") {
                    Picker("Severity", selection: $severity) {
                        ForEach(1...5, id: \.self) { level in
                            Text("\(level)").tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Log Effect")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.bold)
                    .disabled(symptom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let entry = SideEffectEntry(
            date: date,
            symptom: symptom.trimmingCharacters(in: .whitespacesAndNewlines),
            severity: severity,
            notes: notes
        )
        modelContext.insert(entry)
        dismiss()
    }
}
