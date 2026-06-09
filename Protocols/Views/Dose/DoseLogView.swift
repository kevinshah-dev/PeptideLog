import SwiftData
import SwiftUI

struct DoseLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DoseLogEntry.date, order: .reverse) private var doseLogs: [DoseLogEntry]
    @Query(sort: \DoseReminder.nextDoseDate) private var reminders: [DoseReminder]

    @State private var showingDoseSheet = false
    @State private var showingReminderSheet = false

    let openSettings: () -> Void

    private var upcomingReminder: DoseReminder? {
        reminders
            .filter(\.isEnabled)
            .sorted { $0.nextDoseDate < $1.nextDoseDate }
            .first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    summaryGrid

                    SectionHeading(
                        title: "Next Reminder",
                        actionTitle: "Schedule",
                        systemImage: "bell.badge",
                        action: { showingReminderSheet = true }
                    )

                    if let upcomingReminder {
                        ReminderCard(reminder: upcomingReminder) {
                            complete(reminder: upcomingReminder)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(reminder: upcomingReminder)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } else {
                        EmptyStateView(
                            title: "No active reminders",
                            subtitle: "Scheduled reminders appear here once enabled.",
                            systemImage: "bell.slash"
                        )
                    }

                    if !reminders.isEmpty {
                        SectionHeading(title: "Scheduled Reminders")

                        LazyVStack(spacing: 10) {
                            ForEach(reminders, id: \.id) { reminder in
                                ReminderScheduleRow(reminder: reminder) {
                                    refreshSchedule(for: reminder)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        delete(reminder: reminder)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    SectionHeading(
                        title: "Recent Doses",
                        actionTitle: "Log",
                        systemImage: "plus.circle.fill",
                        action: { showingDoseSheet = true }
                    )

                    if doseLogs.isEmpty {
                        EmptyStateView(
                            title: "No doses logged",
                            subtitle: "Your injection history will build a dated local record.",
                            systemImage: "calendar.badge.plus"
                        )
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(doseLogs.prefix(12)), id: \.id) { log in
                                DoseRow(log: log)
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

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingReminderSheet = true
                    } label: {
                        Image(systemName: "bell.badge")
                    }
                    .accessibilityLabel("Schedule reminder")

                    Button {
                        showingDoseSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Log dose")
                }
            }
            .sheet(isPresented: $showingDoseSheet) {
                DoseEntrySheet()
            }
            .sheet(isPresented: $showingReminderSheet) {
                ReminderEntrySheet()
            }
        }
    }

    private var header: some View {
        AppPanel {
            HStack(alignment: .center, spacing: 14) {
                BrandMark()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dose Command")
                        .font(.title2.weight(.black))

                    Text("Local logs, reminders, and injection-site history.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var summaryGrid: some View {
        let lastDose = doseLogs.first
        let weeklyCount = doseLogs.filter {
            $0.date >= Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        }.count

        return HStack(spacing: 10) {
            MetricTile(
                title: "Last dose",
                value: lastDose?.formattedDose ?? "None",
                detail: lastDose?.peptideName ?? "No record",
                systemImage: "syringe",
                tint: AppTheme.accent
            )

            MetricTile(
                title: "7-day logs",
                value: "\(weeklyCount)",
                detail: "entries",
                systemImage: "calendar",
                tint: AppTheme.blue
            )
        }
    }

    private func complete(reminder: DoseReminder) {
        let log = DoseLogEntry(
            peptideName: reminder.peptideName,
            date: .now,
            doseAmount: reminder.doseAmount,
            unit: reminder.doseUnit,
            injectionSite: reminder.injectionSite,
            notes: "Logged from reminder."
        )
        modelContext.insert(log)

        var nextDate = Calendar.current.date(
            byAdding: .day,
            value: reminder.repeatIntervalDays,
            to: reminder.nextDoseDate
        ) ?? .now

        while nextDate < .now {
            nextDate = Calendar.current.date(
                byAdding: .day,
                value: reminder.repeatIntervalDays,
                to: nextDate
            ) ?? .now
        }

        reminder.nextDoseDate = nextDate
        let snapshot = reminder.snapshot

        Task {
            await NotificationScheduler.scheduleDoseReminder(snapshot)
        }
    }

    private func refreshSchedule(for reminder: DoseReminder) {
        let snapshot = reminder.snapshot

        if snapshot.isEnabled {
            Task {
                await NotificationScheduler.scheduleDoseReminder(snapshot)
            }
        } else {
            NotificationScheduler.cancelDoseReminder(identifier: snapshot.identifier)
        }
    }

    private func delete(reminder: DoseReminder) {
        NotificationScheduler.cancelDoseReminder(identifier: reminder.notificationIdentifier)
        modelContext.delete(reminder)
    }
}

private struct ReminderCard: View {
    let reminder: DoseReminder
    let complete: () -> Void

    var body: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .foregroundStyle(AppTheme.accent)
                        .font(.title2)
                        .frame(width: 34)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(reminder.peptideName)
                            .font(.headline.weight(.bold))

                        Text("\(reminder.formattedDose) • \(reminder.injectionSiteRawValue)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)

                        Text(reminder.nextDoseDate.formatted(.dateTime.weekday().month().day().hour().minute()))
                            .font(.subheadline.weight(.semibold))
                    }

                    Spacer()
                }

                HStack {
                    Label("Every \(reminder.repeatIntervalDays) day\(reminder.repeatIntervalDays == 1 ? "" : "s")", systemImage: "repeat")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)

                    Spacer()

                    Button(action: complete) {
                        Label("Mark Complete", systemImage: "checkmark.circle.fill")
                    }
                    .font(.subheadline.weight(.bold))
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .foregroundStyle(.black)
                }
            }
        }
    }
}

private struct DoseRow: View {
    let log: DoseLogEntry

    var body: some View {
        AppPanel(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "syringe")
                    .foregroundStyle(AppTheme.accent)
                    .font(.title3.weight(.semibold))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(log.peptideName)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)

                        Spacer()

                        Text(log.formattedDose)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Text("\(log.injectionSiteRawValue) • \(log.date.formatted(.dateTime.month().day().hour().minute()))")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    if !log.notes.isEmpty {
                        Text(log.notes)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct ReminderScheduleRow: View {
    @Bindable var reminder: DoseReminder
    let onChanged: () -> Void

    var body: some View {
        AppPanel(padding: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: reminder.isEnabled ? "bell.fill" : "bell.slash")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(reminder.isEnabled ? AppTheme.accent : AppTheme.textSecondary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.peptideName)
                        .font(.headline.weight(.semibold))

                    Text("\(reminder.formattedDose) • \(reminder.nextDoseDate.formatted(.dateTime.month().day().hour().minute()))")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Toggle("Enabled", isOn: $reminder.isEnabled)
                    .labelsHidden()
                    .tint(AppTheme.accent)
                    .onChange(of: reminder.isEnabled) { _, _ in
                        onChanged()
                    }
            }
        }
    }
}

private struct DoseEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("preferredPeptideName") private var preferredPeptideName = PeptideLibrary.peptideNames.first ?? "Semaglutide"

    @State private var peptideName: String
    @State private var date = Date()
    @State private var doseAmount = 0.25
    @State private var unit = DoseUnit.milligrams
    @State private var injectionSite = InjectionSite.abdomen
    @State private var notes = ""

    init() {
        let defaultPeptide = UserDefaults.standard.string(forKey: "preferredPeptideName")
            ?? PeptideLibrary.peptideNames.first
            ?? "Semaglutide"
        _peptideName = State(initialValue: defaultPeptide)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dose") {
                    Picker("Peptide", selection: $peptideName) {
                        ForEach(PeptideLibrary.orderedPeptideNames(preferredPeptideName: preferredPeptideName), id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

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
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.bold)
                    .disabled(doseAmount <= 0)
                }
            }
        }
    }

    private func save() {
        let entry = DoseLogEntry(
            peptideName: peptideName,
            date: date,
            doseAmount: doseAmount,
            unit: unit,
            injectionSite: injectionSite,
            notes: notes
        )
        modelContext.insert(entry)
        dismiss()
    }
}

private struct ReminderEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("preferredPeptideName") private var preferredPeptideName = PeptideLibrary.peptideNames.first ?? "Semaglutide"

    @State private var peptideName: String
    @State private var nextDoseDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var doseAmount = 0.25
    @State private var unit = DoseUnit.milligrams
    @State private var injectionSite = InjectionSite.abdomen
    @State private var repeatIntervalDays = 7

    init() {
        let defaultPeptide = UserDefaults.standard.string(forKey: "preferredPeptideName")
            ?? PeptideLibrary.peptideNames.first
            ?? "Semaglutide"
        _peptideName = State(initialValue: defaultPeptide)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder") {
                    Picker("Peptide", selection: $peptideName) {
                        ForEach(PeptideLibrary.orderedPeptideNames(preferredPeptideName: preferredPeptideName), id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

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
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.bold)
                    .disabled(doseAmount <= 0)
                }
            }
        }
    }

    private func save() {
        let reminder = DoseReminder(
            peptideName: peptideName,
            doseAmount: doseAmount,
            unit: unit,
            injectionSite: injectionSite,
            nextDoseDate: nextDoseDate,
            repeatIntervalDays: repeatIntervalDays
        )
        modelContext.insert(reminder)
        let snapshot = reminder.snapshot

        Task {
            await NotificationScheduler.scheduleDoseReminder(snapshot)
        }

        dismiss()
    }
}
