import Charts
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

private enum ProgressWindow: String, CaseIterable, Identifiable {
    case thirty = "30D"
    case ninety = "90D"
    case oneEighty = "180D"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .thirty: 30
        case .ninety: 90
        case .oneEighty: 180
        }
    }
}

struct ProgressTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMeasurementEntry.date) private var measurements: [BodyMeasurementEntry]
    @Query(sort: \ProgressPhotoEntry.date, order: .reverse) private var photos: [ProgressPhotoEntry]

    @State private var selectedWindow = ProgressWindow.thirty
    @State private var showingMeasurementSheet = false
    @State private var showingPhotoSheet = false

    private var filteredMeasurements: [BodyMeasurementEntry] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -selectedWindow.days, to: .now) else {
            return measurements
        }

        return measurements.filter { $0.date >= cutoff }
    }

    private var latestMeasurement: BodyMeasurementEntry? {
        measurements.sorted { $0.date < $1.date }.last
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    progressSummary
                    chartPanel

                    SectionHeading(
                        title: "Measurements",
                        actionTitle: "Log",
                        systemImage: "plus.circle.fill",
                        action: { showingMeasurementSheet = true }
                    )

                    measurementList

                    SectionHeading(
                        title: "Progress Photos",
                        actionTitle: "Add",
                        systemImage: "camera.fill",
                        action: { showingPhotoSheet = true }
                    )

                    photoGrid
                }
                .padding(18)
            }
            .protocolsScreen()
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingPhotoSheet = true
                    } label: {
                        Image(systemName: "camera.fill")
                    }
                    .accessibilityLabel("Add progress photo")

                    Button {
                        showingMeasurementSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Log measurement")
                }
            }
            .sheet(isPresented: $showingMeasurementSheet) {
                MeasurementEntrySheet()
            }
            .sheet(isPresented: $showingPhotoSheet) {
                PhotoEntrySheet()
            }
        }
    }

    private var progressSummary: some View {
        let latest = latestMeasurement
        let firstInWindow = filteredMeasurements.first
        let change = latest.flatMap { latest in
            firstInWindow.map { latest.weight - $0.weight }
        }

        return HStack(spacing: 10) {
            MetricTile(
                title: "Current weight",
                value: latest.map { "\($0.weight.peptideFormatted) lb" } ?? "None",
                detail: latest?.date.formatted(.dateTime.month().day()) ?? "No record",
                systemImage: "scalemass",
                tint: AppTheme.accent
            )

            MetricTile(
                title: "Window change",
                value: change.map { "\($0 >= 0 ? "+" : "")\($0.peptideFormatted) lb" } ?? "None",
                detail: selectedWindow.rawValue,
                systemImage: "arrow.up.and.down",
                tint: AppTheme.blue
            )
        }
    }

    private var chartPanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Weight Trend")
                        .font(.headline.weight(.semibold))

                    Spacer()

                    Picker("Window", selection: $selectedWindow) {
                        ForEach(ProgressWindow.allCases) { window in
                            Text(window.rawValue).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 210)
                }

                if filteredMeasurements.count < 2 {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)

                        Text("More data needed")
                            .font(.headline.weight(.semibold))

                        Text("The line chart appears after at least two weight entries in the selected window.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 8)
                } else {
                    Chart(filteredMeasurements, id: \.id) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(AppTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(AppTheme.accent)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 240)
                }
            }
        }
    }

    private var measurementList: some View {
        Group {
            if measurements.isEmpty {
                EmptyStateView(
                    title: "No measurements",
                    subtitle: "Weight, waist, and other metrics appear here by date.",
                    systemImage: "ruler"
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(measurements.sorted { $0.date > $1.date }.prefix(8), id: \.id) { entry in
                        MeasurementRow(entry: entry)
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
    }

    private var photoGrid: some View {
        Group {
            if photos.isEmpty {
                EmptyStateView(
                    title: "No photos",
                    subtitle: "Progress photos stay local and attach to dated entries.",
                    systemImage: "photo"
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(photos, id: \.id) { photo in
                        ProgressPhotoCard(photo: photo)
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(photo)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
}

private struct MeasurementRow: View {
    let entry: BodyMeasurementEntry

    var body: some View {
        AppPanel(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(entry.date.formatted(.dateTime.month().day().year()))
                        .font(.headline.weight(.bold))

                    Spacer()

                    Text("\(entry.weight.peptideFormatted) lb")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                    if let waist = entry.waist {
                        MeasurementChip(label: "Waist", value: "\(waist.peptideFormatted) in")
                    }
                    if let hip = entry.hip {
                        MeasurementChip(label: "Hip", value: "\(hip.peptideFormatted) in")
                    }
                    if let chest = entry.chest {
                        MeasurementChip(label: "Chest", value: "\(chest.peptideFormatted) in")
                    }
                    if let bodyFat = entry.bodyFatPercentage {
                        MeasurementChip(label: "Body Fat", value: "\(bodyFat.peptideFormatted)%")
                    }
                }

                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct MeasurementChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(AppTheme.elevatedStrong)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProgressPhotoCard: View {
    let photo: ProgressPhotoEntry

    var body: some View {
        AppPanel(padding: 8) {
            VStack(alignment: .leading, spacing: 8) {
                if let imageData = photo.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 170)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Rectangle()
                        .fill(AppTheme.elevatedStrong)
                        .frame(height: 170)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                }

                Text(photo.date.formatted(.dateTime.month().day().year()))
                    .font(.caption.weight(.bold))

                if !photo.caption.isEmpty {
                    Text(photo.caption)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

private struct MeasurementEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date()
    @State private var weight = ""
    @State private var waist = ""
    @State private var hip = ""
    @State private var chest = ""
    @State private var bodyFat = ""
    @State private var notes = ""

    private var weightValue: Double? {
        Double(weight.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Primary") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    TextField("Weight", text: $weight)
                        .keyboardType(.decimalPad)
                }

                Section("Measurements") {
                    TextField("Waist inches", text: $waist)
                        .keyboardType(.decimalPad)

                    TextField("Hip inches", text: $hip)
                        .keyboardType(.decimalPad)

                    TextField("Chest inches", text: $chest)
                        .keyboardType(.decimalPad)

                    TextField("Body fat %", text: $bodyFat)
                        .keyboardType(.decimalPad)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Log Progress")
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
                    .disabled((weightValue ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        guard let weightValue, weightValue > 0 else { return }

        let entry = BodyMeasurementEntry(
            date: date,
            weight: weightValue,
            waist: Double(waist),
            hip: Double(hip),
            chest: Double(chest),
            bodyFatPercentage: Double(bodyFat),
            notes: notes
        )
        modelContext.insert(entry)
        dismiss()
    }
}

private struct PhotoEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date()
    @State private var caption = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label(imageData == nil ? "Choose Photo" : "Change Photo", systemImage: "photo.on.rectangle")
                    }

                    if let imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 240)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                Section("Entry") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    TextField("Caption", text: $caption, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Add Photo")
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    imageData = try? await newItem?.loadTransferable(type: Data.self)
                }
            }
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
                    .disabled(imageData == nil)
                }
            }
        }
    }

    private func save() {
        let entry = ProgressPhotoEntry(
            date: date,
            caption: caption,
            imageData: imageData
        )
        modelContext.insert(entry)
        dismiss()
    }
}
