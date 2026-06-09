import Charts
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct ProtocolsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PeptideProtocol.createdAt, order: .reverse) private var protocols: [PeptideProtocol]
    @Query(sort: \DoseLogEntry.date, order: .reverse) private var doseLogs: [DoseLogEntry]
    @Query(sort: \DoseReminder.nextDoseDate) private var reminders: [DoseReminder]
    @Query(sort: \SideEffectEntry.date, order: .reverse) private var effects: [SideEffectEntry]
    @Query(sort: \BodyMeasurementEntry.date) private var measurements: [BodyMeasurementEntry]

    @State private var showingNewProtocol = false

    let openSettings: () -> Void

    private var activeProtocols: [PeptideProtocol] {
        protocols.filter { $0.status != .completed }
    }

    private var completedProtocols: [PeptideProtocol] {
        protocols.filter { $0.status == .completed }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dashboardHeader

                    SectionHeading(
                        title: "Active Protocols",
                        actionTitle: "New",
                        systemImage: "plus.circle.fill",
                        action: { showingNewProtocol = true }
                    )

                    if activeProtocols.isEmpty {
                        EmptyStateView(
                            title: "No active protocols",
                            subtitle: "Create a protocol to connect dosing, titration, effects, and progress around one peptide.",
                            systemImage: "square.stack.3d.up"
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(activeProtocols, id: \.id) { peptideProtocol in
                                NavigationLink {
                                    ProtocolDetailView(peptideProtocol: peptideProtocol)
                                } label: {
                                    ProtocolDashboardCard(
                                        peptideProtocol: peptideProtocol,
                                        doseLogs: doseLogs,
                                        reminders: reminders,
                                        effects: effects,
                                        measurements: measurements
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        toggle(peptideProtocol)
                                    } label: {
                                        Label(
                                            peptideProtocol.status == .paused ? "Resume" : "Pause",
                                            systemImage: peptideProtocol.status == .paused ? "play.fill" : "pause.fill"
                                        )
                                    }

                                    Button {
                                        modelContext.insert(peptideProtocol.cloned())
                                    } label: {
                                        Label("Clone", systemImage: "square.on.square")
                                    }
                                }
                            }
                        }
                    }

                    if !completedProtocols.isEmpty {
                        SectionHeading(title: "Completed")

                        LazyVStack(spacing: 10) {
                            ForEach(completedProtocols, id: \.id) { peptideProtocol in
                                NavigationLink {
                                    ProtocolDetailView(peptideProtocol: peptideProtocol)
                                } label: {
                                    ProtocolCompactRow(peptideProtocol: peptideProtocol)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(18)
            }
            .protocolsScreen()
            .navigationTitle("Protocols")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: openSettings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewProtocol = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("New protocol")
                }
            }
            .sheet(isPresented: $showingNewProtocol) {
                ProtocolEditorSheet()
            }
        }
    }

    private var dashboardHeader: some View {
        AppPanel {
            HStack(alignment: .center, spacing: 14) {
                ProtocolDashboardIcon()

                VStack(alignment: .leading, spacing: 5) {
                    Text("Dashboard")
                        .font(.title2.weight(.black))

                    Text("Each peptide lives as one connected protocol with dosing, titration, effects, and progress.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func toggle(_ peptideProtocol: PeptideProtocol) {
        switch peptideProtocol.status {
        case .active:
            peptideProtocol.pause()
        case .paused:
            peptideProtocol.resume()
        case .completed:
            peptideProtocol.status = .active
        }
    }
}

private struct ProtocolDashboardIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.elevatedStrong)

            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 30, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)
        }
        .frame(width: 58, height: 58)
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(AppTheme.accent)
                .frame(width: 10, height: 10)
                .padding(11)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.divider)
        }
        .accessibilityHidden(true)
    }
}

private struct ProtocolDashboardCard: View {
    let peptideProtocol: PeptideProtocol
    let doseLogs: [DoseLogEntry]
    let reminders: [DoseReminder]
    let effects: [SideEffectEntry]
    let measurements: [BodyMeasurementEntry]

    private var protocolDoseLogs: [DoseLogEntry] {
        doseLogs.filter { $0.belongs(to: peptideProtocol) }
    }

    private var protocolEffects: [SideEffectEntry] {
        effects.filter { $0.belongs(to: peptideProtocol) }
    }

    private var latestMeasurement: BodyMeasurementEntry? {
        measurements.filter { $0.belongs(to: peptideProtocol) }.max { $0.date < $1.date }
    }

    var body: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(peptideProtocol.name)
                            .font(.title3.weight(.black))
                            .lineLimit(2)

                        Text(peptideProtocol.peptideName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Spacer()

                    ProtocolStatusChip(status: peptideProtocol.status)
                }

                HStack(spacing: 10) {
                    ProtocolMiniMetric(
                        title: "Current",
                        value: peptideProtocol.formattedCurrentDose,
                        systemImage: "gauge.with.dots.needle.bottom.50percent",
                        tint: AppTheme.accent
                    )

                    ProtocolMiniMetric(
                        title: "Next dose",
                        value: nextDoseCopy,
                        systemImage: "calendar.badge.clock",
                        tint: AppTheme.blue
                    )
                }

                HStack(spacing: 10) {
                    ProtocolMiniMetric(
                        title: "Doses",
                        value: "\(protocolDoseLogs.count)",
                        systemImage: "syringe",
                        tint: AppTheme.accent
                    )

                    ProtocolMiniMetric(
                        title: "Effects",
                        value: "\(protocolEffects.count)",
                        systemImage: "waveform.path.ecg",
                        tint: effectTint
                    )

                    ProtocolMiniMetric(
                        title: "Weight",
                        value: latestMeasurement.map { "\($0.weight.peptideFormatted) lb" } ?? "None",
                        systemImage: "scalemass",
                        tint: AppTheme.warning
                    )
                }
            }
        }
    }

    private var nextDoseCopy: String {
        guard peptideProtocol.status == .active else { return peptideProtocol.status.rawValue }
        guard let date = peptideProtocol.nextDoseDate(from: doseLogs, reminders: reminders) else { return "None" }
        return date.formatted(.dateTime.month().day())
    }

    private var effectTint: Color {
        let highSeverity = protocolEffects.contains { $0.severity >= 4 }
        return highSeverity ? AppTheme.danger : AppTheme.blue
    }
}

private struct ProtocolCompactRow: View {
    let peptideProtocol: PeptideProtocol

    var body: some View {
        AppPanel(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(peptideProtocol.name)
                        .font(.headline.weight(.semibold))
                    Text(peptideProtocol.peptideName)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

private struct ProtocolDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var peptideProtocol: PeptideProtocol

    @Query(sort: \DoseLogEntry.date, order: .reverse) private var doseLogs: [DoseLogEntry]
    @Query(sort: \DoseReminder.nextDoseDate) private var reminders: [DoseReminder]
    @Query(sort: \SideEffectEntry.date, order: .reverse) private var effects: [SideEffectEntry]
    @Query(sort: \BodyMeasurementEntry.date) private var measurements: [BodyMeasurementEntry]
    @Query(sort: \ProgressPhotoEntry.date, order: .reverse) private var photos: [ProgressPhotoEntry]

    @State private var showingDoseSheet = false
    @State private var showingReminderSheet = false
    @State private var showingEffectSheet = false
    @State private var showingMeasurementSheet = false
    @State private var showingPhotoSheet = false

    private var protocolDoseLogs: [DoseLogEntry] {
        doseLogs.filter { $0.belongs(to: peptideProtocol) }
    }

    private var protocolReminders: [DoseReminder] {
        reminders.filter { $0.belongs(to: peptideProtocol) }
    }

    private var protocolEffects: [SideEffectEntry] {
        effects.filter { $0.belongs(to: peptideProtocol) }
    }

    private var protocolMeasurements: [BodyMeasurementEntry] {
        measurements.filter { $0.belongs(to: peptideProtocol) }
    }

    private var protocolPhotos: [ProgressPhotoEntry] {
        photos.filter { $0.belongs(to: peptideProtocol) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader
                actionGrid
                schedulePanel
                titrationPanel
                doseHistory
                effectsTimeline
                progressPanel
                photosPanel
            }
            .padding(18)
        }
        .protocolsScreen()
        .navigationTitle(peptideProtocol.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        toggleStatus()
                    } label: {
                        Label(
                            peptideProtocol.status == .paused ? "Resume Protocol" : "Pause Protocol",
                            systemImage: peptideProtocol.status == .paused ? "play.fill" : "pause.fill"
                        )
                    }
                    .disabled(peptideProtocol.status == .completed)

                    Button {
                        modelContext.insert(peptideProtocol.cloned())
                    } label: {
                        Label("Clone Protocol", systemImage: "square.on.square")
                    }

                    Button {
                        peptideProtocol.status = .completed
                    } label: {
                        Label("Mark Completed", systemImage: "checkmark.seal")
                    }
                    .disabled(peptideProtocol.status == .completed)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingDoseSheet) {
            ProtocolDoseEntrySheet(peptideProtocol: peptideProtocol)
        }
        .sheet(isPresented: $showingReminderSheet) {
            ProtocolReminderSheet(peptideProtocol: peptideProtocol)
        }
        .sheet(isPresented: $showingEffectSheet) {
            ProtocolEffectSheet(peptideProtocol: peptideProtocol)
        }
        .sheet(isPresented: $showingMeasurementSheet) {
            ProtocolMeasurementSheet(peptideProtocol: peptideProtocol)
        }
        .sheet(isPresented: $showingPhotoSheet) {
            ProtocolPhotoSheet(peptideProtocol: peptideProtocol)
        }
    }

    private var detailHeader: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(peptideProtocol.name)
                            .font(.largeTitle.weight(.black))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(peptideProtocol.peptideName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Spacer()

                    ProtocolStatusChip(status: peptideProtocol.status)
                }

                Text("Started \(peptideProtocol.startedOn.formatted(.dateTime.month().day().year())) • Dose every \(peptideProtocol.repeatIntervalDays) day\(peptideProtocol.repeatIntervalDays == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                if !peptideProtocol.notes.isEmpty {
                    Text(peptideProtocol.notes)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            ProtocolActionButton(title: "Log Dose", systemImage: "syringe", action: { showingDoseSheet = true })
            ProtocolActionButton(title: "Reminder", systemImage: "bell.badge", action: { showingReminderSheet = true })
            ProtocolActionButton(title: "Log Effect", systemImage: "waveform.path.ecg", action: { showingEffectSheet = true })
            ProtocolActionButton(title: "Progress", systemImage: "scalemass", action: { showingMeasurementSheet = true })
            ProtocolActionButton(title: "Photo", systemImage: "camera.fill", action: { showingPhotoSheet = true })
        }
    }

    private var schedulePanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Dosing Schedule")
                    .font(.headline.weight(.semibold))

                HStack(spacing: 10) {
                    ProtocolMiniMetric(
                        title: "Phase \(peptideProtocol.phaseIndex() + 1)",
                        value: peptideProtocol.formattedCurrentDose,
                        systemImage: "gauge.with.dots.needle.bottom.50percent",
                        tint: AppTheme.accent
                    )

                    ProtocolMiniMetric(
                        title: peptideProtocol.status.rawValue,
                        value: nextDoseCopy,
                        systemImage: "calendar.badge.clock",
                        tint: AppTheme.blue
                    )
                }

                if protocolReminders.isEmpty {
                    Text("No scheduled reminders for this protocol.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(protocolReminders, id: \.id) { reminder in
                            ProtocolReminderRow(reminder: reminder)
                        }
                    }
                }
            }
        }
    }

    private var titrationPanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Titration Curve")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Text(nextTitrationCopy)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(spacing: 0) {
                    let steps = peptideProtocol.projectedSteps()
                    ForEach(Array(steps.enumerated()), id: \.element.id) { offset, step in
                        ProtocolTimelineStepRow(
                            step: step,
                            unit: peptideProtocol.unitRawValue,
                            isCurrent: step.index == peptideProtocol.phaseIndex(),
                            isComplete: step.index < peptideProtocol.phaseIndex(),
                            isLast: offset == steps.count - 1
                        )
                    }
                }
            }
        }
    }

    private var doseHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Dose History", actionTitle: "Log", systemImage: "plus.circle.fill") {
                showingDoseSheet = true
            }

            if protocolDoseLogs.isEmpty {
                EmptyStateView(
                    title: "No doses logged",
                    subtitle: "Dose entries for this protocol will appear here.",
                    systemImage: "calendar.badge.plus"
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(protocolDoseLogs.prefix(8)), id: \.id) { log in
                        ProtocolDoseRow(log: log)
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(log)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    private var effectsTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Effects", actionTitle: "Log", systemImage: "plus.circle.fill") {
                showingEffectSheet = true
            }

            if protocolEffects.isEmpty {
                EmptyStateView(
                    title: "No effects tracked",
                    subtitle: "Symptom and side-effect entries stay tied to this peptide protocol.",
                    systemImage: "waveform.path.ecg"
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(protocolEffects.prefix(8)), id: \.id) { effect in
                        ProtocolEffectRow(entry: effect)
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(effect)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    private var progressPanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Progress")
                        .font(.headline.weight(.semibold))

                    Spacer()

                    Button {
                        showingMeasurementSheet = true
                    } label: {
                        Label("Log", systemImage: "plus.circle.fill")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                }

                if protocolMeasurements.count >= 2 {
                    Chart(protocolMeasurements, id: \.id) { entry in
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
                    .frame(height: 200)
                } else {
                    Text("Log at least two weight entries to show this protocol's trend.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if !protocolMeasurements.isEmpty {
                    LazyVStack(spacing: 8) {
                        ForEach(protocolMeasurements.sorted { $0.date > $1.date }.prefix(4), id: \.id) { measurement in
                            ProtocolMeasurementRow(entry: measurement)
                        }
                    }
                }
            }
        }
    }

    private var photosPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Photos", actionTitle: "Add", systemImage: "camera.fill") {
                showingPhotoSheet = true
            }

            if protocolPhotos.isEmpty {
                EmptyStateView(
                    title: "No photos",
                    subtitle: "Progress photos attached here stay with this protocol.",
                    systemImage: "photo"
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(protocolPhotos, id: \.id) { photo in
                        ProtocolPhotoCard(photo: photo)
                    }
                }
            }
        }
    }

    private var nextDoseCopy: String {
        guard peptideProtocol.status == .active else { return peptideProtocol.status.rawValue }
        guard let date = peptideProtocol.nextDoseDate(from: protocolDoseLogs, reminders: protocolReminders) else { return "None" }
        return date.formatted(.dateTime.month().day())
    }

    private var nextTitrationCopy: String {
        guard let date = peptideProtocol.nextTitrationDate() else { return "Target reached" }
        return "Next \(date.formatted(.dateTime.month().day()))"
    }

    private func toggleStatus() {
        switch peptideProtocol.status {
        case .active:
            peptideProtocol.pause()
        case .paused:
            peptideProtocol.resume()
        case .completed:
            break
        }
    }
}

private struct ProtocolStatusChip: View {
    let status: ProtocolStatus

    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.caption2.weight(.black))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(tint.opacity(0.16))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }

    private var tint: Color {
        switch status {
        case .active: AppTheme.accent
        case .paused: AppTheme.warning
        case .completed: AppTheme.textSecondary
        }
    }
}

private struct ProtocolMiniMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)

            Text(value)
                .font(.headline.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.elevatedStrong)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProtocolActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .buttonStyle(.bordered)
        .tint(AppTheme.accent)
    }
}

private struct ProtocolTimelineStepRow: View {
    let step: TitrationStep
    let unit: String
    let isCurrent: Bool
    let isComplete: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 18, height: 18)
                    .overlay {
                        if isCurrent {
                            Circle()
                                .stroke(AppTheme.accent.opacity(0.35), lineWidth: 8)
                        }
                    }

                Rectangle()
                    .fill(AppTheme.divider)
                    .frame(width: 2, height: 42)
                    .opacity(isLast ? 0 : 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Phase \(step.index + 1)")
                        .font(.headline.weight(.semibold))

                    if isCurrent {
                        Text("CURRENT")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(AppTheme.accent)
                            .clipShape(Capsule())
                    }
                }

                Text("\(step.dose.peptideFormatted) \(unit) • \(step.date.formatted(.dateTime.month().day().year()))")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
    }

    private var indicatorColor: Color {
        if isCurrent { return AppTheme.accent }
        if isComplete { return AppTheme.blue }
        return AppTheme.divider
    }
}

private struct ProtocolReminderRow: View {
    @Bindable var reminder: DoseReminder

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: reminder.isEnabled ? "bell.fill" : "bell.slash")
                .foregroundStyle(reminder.isEnabled ? AppTheme.accent : AppTheme.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.nextDoseDate.formatted(.dateTime.month().day().hour().minute()))
                    .font(.subheadline.weight(.semibold))
                Text("\(reminder.formattedDose) • every \(reminder.repeatIntervalDays) day\(reminder.repeatIntervalDays == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Toggle("Enabled", isOn: $reminder.isEnabled)
                .labelsHidden()
                .tint(AppTheme.accent)
                .onChange(of: reminder.isEnabled) { _, isEnabled in
                    if isEnabled {
                        Task { await NotificationScheduler.scheduleDoseReminder(reminder.snapshot) }
                    } else {
                        NotificationScheduler.cancelDoseReminder(identifier: reminder.notificationIdentifier)
                    }
                }
        }
        .padding(10)
        .background(AppTheme.elevatedStrong)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProtocolDoseRow: View {
    let log: DoseLogEntry

    var body: some View {
        AppPanel(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "syringe")
                    .foregroundStyle(AppTheme.accent)
                    .font(.title3.weight(.semibold))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.formattedDose)
                            .font(.headline.weight(.bold))
                        Spacer()
                        Text(log.date.formatted(.dateTime.month().day().hour().minute()))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Text(log.injectionSiteRawValue)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    if !log.notes.isEmpty {
                        Text(log.notes)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
    }
}

private struct ProtocolEffectRow: View {
    let entry: SideEffectEntry

    var body: some View {
        AppPanel(padding: 14) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(entry.symptom)
                        .font(.headline.weight(.bold))
                    Spacer()
                    SeverityDots(severity: entry.severity)
                }

                Text(entry.date.formatted(.dateTime.month().day().year().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }
}

private struct ProtocolMeasurementRow: View {
    let entry: BodyMeasurementEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.date.formatted(.dateTime.month().day().year()))
                    .font(.subheadline.weight(.semibold))
                Text(measurementDetail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text("\(entry.weight.peptideFormatted) lb")
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.accent)
        }
        .padding(10)
        .background(AppTheme.elevatedStrong)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var measurementDetail: String {
        var parts: [String] = []
        if let waist = entry.waist { parts.append("Waist \(waist.peptideFormatted) in") }
        if let bodyFat = entry.bodyFatPercentage { parts.append("BF \(bodyFat.peptideFormatted)%") }
        return parts.isEmpty ? "Measurement entry" : parts.joined(separator: " • ")
    }
}

private struct ProtocolPhotoCard: View {
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

private struct ProtocolEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("preferredPeptideName") private var preferredPeptideName = PeptideLibrary.peptideNames.first ?? "Semaglutide"

    @State private var peptideName: String
    @State private var name: String
    @State private var startedOn = Date()
    @State private var startingDose = ""
    @State private var targetDose = ""
    @State private var stepIncrease = ""
    @State private var escalationIntervalDays = 28
    @State private var repeatIntervalDays = 7
    @State private var unit = DoseUnit.milligrams
    @State private var injectionSite = InjectionSite.abdomen
    @State private var notes = ""

    init() {
        let defaultPeptide = UserDefaults.standard.string(forKey: "preferredPeptideName")
            ?? PeptideLibrary.peptideNames.first
            ?? "Semaglutide"
        _peptideName = State(initialValue: defaultPeptide)
        _name = State(initialValue: "\(defaultPeptide) Protocol")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Protocol") {
                    TextField("Protocol name", text: $name)

                    Picker("Peptide", selection: $peptideName) {
                        ForEach(PeptideLibrary.orderedPeptideNames(preferredPeptideName: preferredPeptideName), id: \.self) { peptide in
                            Text(peptide).tag(peptide)
                        }
                    }
                    .onChange(of: peptideName) { _, newValue in
                        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.hasSuffix("Protocol") {
                            name = "\(newValue) Protocol"
                        }
                    }

                    DatePicker("Start date", selection: $startedOn, displayedComponents: .date)
                }

                Section("Dosing") {
                    TextField("Starting Dose (e.g. 0.25)", text: $startingDose)
                        .keyboardType(.decimalPad)
                    TextField("Target Dose (e.g. 2.4)", text: $targetDose)
                        .keyboardType(.decimalPad)
                    TextField("Step Increase (e.g. 0.25)", text: $stepIncrease)
                        .keyboardType(.decimalPad)

                    Picker("Unit", selection: $unit) {
                        ForEach(DoseUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Default injection site", selection: $injectionSite) {
                        ForEach(InjectionSite.allCases) { site in
                            Text(site.rawValue).tag(site)
                        }
                    }
                }

                Section("Schedule") {
                    Stepper("Dose every \(repeatIntervalDays) day\(repeatIntervalDays == 1 ? "" : "s")", value: $repeatIntervalDays, in: 1...60)
                    Stepper("Titrate every \(escalationIntervalDays) day\(escalationIntervalDays == 1 ? "" : "s")", value: $escalationIntervalDays, in: 1...90)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("New Protocol")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { save() }
                        .fontWeight(.bold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        guard let startingDoseValue,
              let targetDoseValue,
              let stepIncreaseValue else {
            return false
        }

        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && startingDoseValue > 0
            && targetDoseValue >= startingDoseValue
            && stepIncreaseValue > 0
    }

    private func save() {
        guard let startingDoseValue,
              let targetDoseValue,
              let stepIncreaseValue else { return }

        let peptideProtocol = PeptideProtocol(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            peptideName: peptideName,
            startedOn: startedOn,
            startingDose: startingDoseValue,
            targetDose: targetDoseValue,
            stepIncrease: stepIncreaseValue,
            escalationIntervalDays: escalationIntervalDays,
            repeatIntervalDays: repeatIntervalDays,
            unit: unit,
            injectionSite: injectionSite,
            notes: notes
        )
        modelContext.insert(peptideProtocol)
        dismiss()
    }

    private var startingDoseValue: Double? {
        Double(startingDose.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var targetDoseValue: Double? {
        Double(targetDose.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var stepIncreaseValue: Double? {
        Double(stepIncrease.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private struct ProtocolDoseEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let peptideProtocol: PeptideProtocol

    @State private var date = Date()
    @State private var doseAmount: Double
    @State private var unit: DoseUnit
    @State private var injectionSite: InjectionSite
    @State private var notes = ""

    init(peptideProtocol: PeptideProtocol) {
        self.peptideProtocol = peptideProtocol
        _doseAmount = State(initialValue: peptideProtocol.currentDose())
        _unit = State(initialValue: peptideProtocol.doseUnit)
        _injectionSite = State(initialValue: peptideProtocol.injectionSite)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dose") {
                    TextField("Amount", value: $doseAmount, format: .number)
                        .keyboardType(.decimalPad)

                    Picker("Unit", selection: $unit) {
                        ForEach(DoseUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Timing") {
                    DatePicker("Date", selection: $date)

                    Picker("Injection site", selection: $injectionSite) {
                        ForEach(InjectionSite.allCases) { site in
                            Text(site.rawValue).tag(site)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Log Dose")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(doseAmount <= 0)
                }
            }
        }
    }

    private func save() {
        modelContext.insert(
            DoseLogEntry(
                protocolID: peptideProtocol.id,
                peptideName: peptideProtocol.peptideName,
                date: date,
                doseAmount: doseAmount,
                unit: unit,
                injectionSite: injectionSite,
                notes: notes
            )
        )
        dismiss()
    }
}

private struct ProtocolReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let peptideProtocol: PeptideProtocol

    @State private var nextDoseDate: Date
    @State private var doseAmount: Double
    @State private var unit: DoseUnit
    @State private var injectionSite: InjectionSite
    @State private var repeatIntervalDays: Int

    init(peptideProtocol: PeptideProtocol) {
        self.peptideProtocol = peptideProtocol
        _nextDoseDate = State(initialValue: Calendar.current.date(byAdding: .day, value: peptideProtocol.repeatIntervalDays, to: .now) ?? .now)
        _doseAmount = State(initialValue: peptideProtocol.currentDose())
        _unit = State(initialValue: peptideProtocol.doseUnit)
        _injectionSite = State(initialValue: peptideProtocol.injectionSite)
        _repeatIntervalDays = State(initialValue: peptideProtocol.repeatIntervalDays)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder") {
                    DatePicker("Next dose", selection: $nextDoseDate)
                    Stepper("Every \(repeatIntervalDays) day\(repeatIntervalDays == 1 ? "" : "s")", value: $repeatIntervalDays, in: 1...60)
                }

                Section("Dose") {
                    TextField("Amount", value: $doseAmount, format: .number)
                        .keyboardType(.decimalPad)

                    Picker("Unit", selection: $unit) {
                        ForEach(DoseUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Injection site", selection: $injectionSite) {
                        ForEach(InjectionSite.allCases) { site in
                            Text(site.rawValue).tag(site)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Schedule Dose")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(doseAmount <= 0)
                }
            }
        }
    }

    private func save() {
        let reminder = DoseReminder(
            protocolID: peptideProtocol.id,
            peptideName: peptideProtocol.peptideName,
            doseAmount: doseAmount,
            unit: unit,
            injectionSite: injectionSite,
            nextDoseDate: nextDoseDate,
            repeatIntervalDays: repeatIntervalDays
        )
        modelContext.insert(reminder)

        Task {
            await NotificationScheduler.scheduleDoseReminder(reminder.snapshot)
        }

        dismiss()
    }
}

private struct ProtocolEffectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let peptideProtocol: PeptideProtocol

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
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(symptom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        modelContext.insert(
            SideEffectEntry(
                protocolID: peptideProtocol.id,
                date: date,
                symptom: symptom.trimmingCharacters(in: .whitespacesAndNewlines),
                severity: severity,
                notes: notes
            )
        )
        dismiss()
    }
}

private struct ProtocolMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let peptideProtocol: PeptideProtocol

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
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled((weightValue ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        guard let weightValue, weightValue > 0 else { return }

        modelContext.insert(
            BodyMeasurementEntry(
                protocolID: peptideProtocol.id,
                date: date,
                weight: weightValue,
                waist: Double(waist),
                hip: Double(hip),
                chest: Double(chest),
                bodyFatPercentage: Double(bodyFat),
                notes: notes
            )
        )
        dismiss()
    }
}

private struct ProtocolPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let peptideProtocol: PeptideProtocol

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
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(imageData == nil)
                }
            }
        }
    }

    private func save() {
        modelContext.insert(
            ProgressPhotoEntry(
                protocolID: peptideProtocol.id,
                date: date,
                caption: caption,
                imageData: imageData
            )
        )
        dismiss()
    }
}

private extension DoseLogEntry {
    func belongs(to peptideProtocol: PeptideProtocol) -> Bool {
        protocolIDString == peptideProtocol.id.uuidString
            || (protocolIDString == nil && peptideName == peptideProtocol.peptideName)
    }
}

private extension DoseReminder {
    func belongs(to peptideProtocol: PeptideProtocol) -> Bool {
        protocolIDString == peptideProtocol.id.uuidString
            || (protocolIDString == nil && peptideName == peptideProtocol.peptideName)
    }
}

private extension SideEffectEntry {
    func belongs(to peptideProtocol: PeptideProtocol) -> Bool {
        protocolIDString == peptideProtocol.id.uuidString
    }
}

private extension BodyMeasurementEntry {
    func belongs(to peptideProtocol: PeptideProtocol) -> Bool {
        protocolIDString == peptideProtocol.id.uuidString
    }
}

private extension ProgressPhotoEntry {
    func belongs(to peptideProtocol: PeptideProtocol) -> Bool {
        protocolIDString == peptideProtocol.id.uuidString
    }
}
