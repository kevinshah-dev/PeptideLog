import SwiftData
import SwiftUI

struct TitrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TitrationPlan.startedOn, order: .reverse) private var plans: [TitrationPlan]

    @State private var showingPlanSheet = false

    private var activePlan: TitrationPlan? {
        plans.first(where: \.isActive) ?? plans.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeading(
                        title: "Titration",
                        actionTitle: "New",
                        systemImage: "plus.circle.fill",
                        action: { showingPlanSheet = true }
                    )

                    if let activePlan {
                        planOverview(activePlan)
                        TitrationTimeline(plan: activePlan)

                        if !activePlan.notes.isEmpty {
                            AppPanel {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Protocol Notes")
                                        .font(.headline.weight(.semibold))
                                    Text(activePlan.notes)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                        }

                        Button(role: .destructive) {
                            activePlan.isActive = false
                        } label: {
                            Label("Archive Active Plan", systemImage: "archivebox")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!activePlan.isActive)
                    } else {
                        EmptyStateView(
                            title: "No titration plan",
                            subtitle: "Create a starting dose, interval, and target dose to track the current phase.",
                            systemImage: "chart.line.uptrend.xyaxis"
                        )
                    }
                }
                .padding(18)
            }
            .protocolsScreen()
            .navigationTitle("Titration")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPlanSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("New titration plan")
                }
            }
            .sheet(isPresented: $showingPlanSheet) {
                TitrationPlanSheet()
            }
        }
    }

    private func planOverview(_ plan: TitrationPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            AppPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.peptideName)
                                .font(.title2.weight(.black))

                            Text("Started \(plan.startedOn.formatted(.dateTime.month().day().year()))")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        Text(plan.isActive ? "ACTIVE" : "ARCHIVED")
                            .font(.caption.weight(.black))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background((plan.isActive ? AppTheme.accent : AppTheme.divider).opacity(0.18))
                            .foregroundStyle(plan.isActive ? AppTheme.accent : AppTheme.textSecondary)
                            .clipShape(Capsule())
                    }

                    Text("Escalates by \(plan.stepIncrease.peptideFormatted) \(plan.unitRawValue) every \(plan.escalationIntervalDays) day\(plan.escalationIntervalDays == 1 ? "" : "s").")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            HStack(spacing: 10) {
                MetricTile(
                    title: "Current",
                    value: "\(plan.currentDose().peptideFormatted) \(plan.unitRawValue)",
                    detail: "phase \(plan.phaseIndex() + 1)",
                    systemImage: "gauge.with.dots.needle.bottom.50percent",
                    tint: AppTheme.accent
                )

                MetricTile(
                    title: "Target",
                    value: "\(plan.targetDose.peptideFormatted) \(plan.unitRawValue)",
                    detail: nextStepCopy(plan),
                    systemImage: "scope",
                    tint: AppTheme.warning
                )
            }
        }
    }

    private func nextStepCopy(_ plan: TitrationPlan) -> String {
        guard let date = plan.nextStepDate() else { return "at target" }
        return date.formatted(.dateTime.month().day())
    }
}

private struct TitrationTimeline: View {
    let plan: TitrationPlan

    var body: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Visual Timeline")
                    .font(.headline.weight(.semibold))

                let steps = plan.projectedSteps()

                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { offset, step in
                        TimelineStepRow(
                            step: step,
                            unit: plan.unitRawValue,
                            isCurrent: step.index == plan.phaseIndex(),
                            isComplete: step.index < plan.phaseIndex(),
                            isLast: offset == steps.count - 1
                        )
                    }
                }
            }
        }
    }
}

private struct TimelineStepRow: View {
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
                                .stroke(AppTheme.accent.opacity(0.4), lineWidth: 8)
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

private struct TitrationPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("preferredPeptideName") private var preferredPeptideName = PeptideLibrary.peptideNames.first ?? "Semaglutide"

    @State private var peptideName: String
    @State private var startedOn = Date()
    @State private var startingDose = ""
    @State private var targetDose = ""
    @State private var stepIncrease = ""
    @State private var escalationIntervalDays = 28
    @State private var unit = DoseUnit.milligrams
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
                Section("Protocol") {
                    Picker("Peptide", selection: $peptideName) {
                        ForEach(PeptideLibrary.orderedPeptideNames(preferredPeptideName: preferredPeptideName), id: \.self) { name in
                            Text(name).tag(name)
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
                }

                Section("Interval") {
                    Stepper(
                        "Every \(escalationIntervalDays) day\(escalationIntervalDays == 1 ? "" : "s")",
                        value: $escalationIntervalDays,
                        in: 1...90
                    )
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("New Titration")
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

        return startingDoseValue > 0
            && targetDoseValue >= startingDoseValue
            && stepIncreaseValue > 0
    }

    private func save() {
        guard let startingDoseValue,
              let targetDoseValue,
              let stepIncreaseValue else { return }

        let plan = TitrationPlan(
            peptideName: peptideName,
            startedOn: startedOn,
            startingDose: startingDoseValue,
            targetDose: targetDoseValue,
            stepIncrease: stepIncreaseValue,
            escalationIntervalDays: escalationIntervalDays,
            unit: unit,
            notes: notes
        )
        modelContext.insert(plan)
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
