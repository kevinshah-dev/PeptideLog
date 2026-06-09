import Foundation
import SwiftData

enum DoseUnit: String, CaseIterable, Identifiable {
    case milligrams = "mg"
    case micrograms = "mcg"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .milligrams: "Milligrams"
        case .micrograms: "Micrograms"
        }
    }
}

enum InjectionSite: String, CaseIterable, Identifiable {
    case abdomen = "Abdomen"
    case thigh = "Thigh"
    case upperArm = "Upper arm"
    case glute = "Glute"
    case other = "Other"

    var id: String { rawValue }
}

enum ProtocolStatus: String, CaseIterable, Identifiable {
    case active = "Active"
    case paused = "Paused"
    case completed = "Completed"

    var id: String { rawValue }
}

@Model
final class PeptideProtocol {
    @Attribute(.unique) var id: UUID
    var name: String
    var peptideName: String
    var createdAt: Date
    var startedOn: Date
    var statusRawValue: String
    var pausedAt: Date?
    var startingDose: Double
    var targetDose: Double
    var stepIncrease: Double
    var escalationIntervalDays: Int
    var repeatIntervalDays: Int
    var unitRawValue: String
    var injectionSiteRawValue: String
    var notes: String

    init(
        name: String,
        peptideName: String,
        createdAt: Date = .now,
        startedOn: Date,
        status: ProtocolStatus = .active,
        startingDose: Double,
        targetDose: Double,
        stepIncrease: Double,
        escalationIntervalDays: Int,
        repeatIntervalDays: Int,
        unit: DoseUnit,
        injectionSite: InjectionSite,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.peptideName = peptideName
        self.createdAt = createdAt
        self.startedOn = startedOn
        self.statusRawValue = status.rawValue
        self.pausedAt = nil
        self.startingDose = startingDose
        self.targetDose = targetDose
        self.stepIncrease = stepIncrease
        self.escalationIntervalDays = max(1, escalationIntervalDays)
        self.repeatIntervalDays = max(1, repeatIntervalDays)
        self.unitRawValue = unit.rawValue
        self.injectionSiteRawValue = injectionSite.rawValue
        self.notes = notes
    }

    var status: ProtocolStatus {
        get { ProtocolStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    var doseUnit: DoseUnit {
        get { DoseUnit(rawValue: unitRawValue) ?? .milligrams }
        set { unitRawValue = newValue.rawValue }
    }

    var injectionSite: InjectionSite {
        get { InjectionSite(rawValue: injectionSiteRawValue) ?? .other }
        set { injectionSiteRawValue = newValue.rawValue }
    }

    var isActive: Bool {
        status == .active
    }

    var formattedCurrentDose: String {
        "\(currentDose().peptideFormatted) \(unitRawValue)"
    }

    func phaseIndex(on date: Date = .now) -> Int {
        let effectiveDate = status == .paused ? (pausedAt ?? date) : date
        guard effectiveDate > startedOn else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: startedOn, to: effectiveDate).day ?? 0
        return max(0, days / escalationIntervalDays)
    }

    func currentDose(on date: Date = .now) -> Double {
        let dose = startingDose + (Double(phaseIndex(on: date)) * stepIncrease)
        return min(max(startingDose, dose), targetDose)
    }

    func nextTitrationDate(after date: Date = .now) -> Date? {
        guard status == .active, currentDose(on: date) < targetDose else { return nil }
        let nextPhase = phaseIndex(on: date) + 1
        return Calendar.current.date(
            byAdding: .day,
            value: nextPhase * escalationIntervalDays,
            to: startedOn
        )
    }

    func nextDoseDate(from entries: [DoseLogEntry], reminders: [DoseReminder]) -> Date? {
        let protocolID = id.uuidString
        if let reminderDate = reminders
            .filter({ ($0.protocolIDString == protocolID || ($0.protocolIDString == nil && $0.peptideName == peptideName)) && $0.isEnabled })
            .map(\.nextDoseDate)
            .min() {
            return reminderDate
        }

        let latestDoseDate = entries
            .filter { $0.protocolIDString == protocolID || ($0.protocolIDString == nil && $0.peptideName == peptideName) }
            .map(\.date)
            .max() ?? startedOn

        return Calendar.current.date(byAdding: .day, value: repeatIntervalDays, to: latestDoseDate)
    }

    func projectedSteps(limit: Int = 24) -> [TitrationStep] {
        var steps: [TitrationStep] = []
        var dose = startingDose
        var index = 0

        while dose <= targetDose && index < limit {
            let date = Calendar.current.date(
                byAdding: .day,
                value: index * escalationIntervalDays,
                to: startedOn
            ) ?? startedOn

            steps.append(TitrationStep(index: index, date: date, dose: min(dose, targetDose)))

            if dose >= targetDose { break }
            dose += stepIncrease
            index += 1
        }

        if let last = steps.last, last.dose < targetDose, index < limit {
            let date = Calendar.current.date(
                byAdding: .day,
                value: (index + 1) * escalationIntervalDays,
                to: startedOn
            ) ?? startedOn
            steps.append(TitrationStep(index: index + 1, date: date, dose: targetDose))
        }

        return steps
    }

    func pause() {
        status = .paused
        pausedAt = .now
    }

    func resume() {
        status = .active
        pausedAt = nil
    }

    func cloned() -> PeptideProtocol {
        PeptideProtocol(
            name: "\(name) Copy",
            peptideName: peptideName,
            startedOn: .now,
            startingDose: startingDose,
            targetDose: targetDose,
            stepIncrease: stepIncrease,
            escalationIntervalDays: escalationIntervalDays,
            repeatIntervalDays: repeatIntervalDays,
            unit: doseUnit,
            injectionSite: injectionSite,
            notes: notes
        )
    }
}

@Model
final class DoseLogEntry {
    @Attribute(.unique) var id: UUID
    var protocolIDString: String?
    var peptideName: String
    var date: Date
    var doseAmount: Double
    var unitRawValue: String
    var injectionSiteRawValue: String
    var notes: String

    init(
        protocolID: UUID? = nil,
        peptideName: String,
        date: Date,
        doseAmount: Double,
        unit: DoseUnit,
        injectionSite: InjectionSite,
        notes: String = ""
    ) {
        self.id = UUID()
        self.protocolIDString = protocolID?.uuidString
        self.peptideName = peptideName
        self.date = date
        self.doseAmount = doseAmount
        self.unitRawValue = unit.rawValue
        self.injectionSiteRawValue = injectionSite.rawValue
        self.notes = notes
    }

    var doseUnit: DoseUnit {
        get { DoseUnit(rawValue: unitRawValue) ?? .milligrams }
        set { unitRawValue = newValue.rawValue }
    }

    var injectionSite: InjectionSite {
        get { InjectionSite(rawValue: injectionSiteRawValue) ?? .other }
        set { injectionSiteRawValue = newValue.rawValue }
    }

    var formattedDose: String {
        "\(doseAmount.peptideFormatted) \(unitRawValue)"
    }
}

@Model
final class DoseReminder {
    @Attribute(.unique) var id: UUID
    var protocolIDString: String?
    var peptideName: String
    var doseAmount: Double
    var unitRawValue: String
    var injectionSiteRawValue: String
    var nextDoseDate: Date
    var repeatIntervalDays: Int
    var isEnabled: Bool
    var notificationIdentifier: String

    init(
        protocolID: UUID? = nil,
        peptideName: String,
        doseAmount: Double,
        unit: DoseUnit,
        injectionSite: InjectionSite,
        nextDoseDate: Date,
        repeatIntervalDays: Int,
        isEnabled: Bool = true
    ) {
        let id = UUID()
        self.id = id
        self.protocolIDString = protocolID?.uuidString
        self.peptideName = peptideName
        self.doseAmount = doseAmount
        self.unitRawValue = unit.rawValue
        self.injectionSiteRawValue = injectionSite.rawValue
        self.nextDoseDate = nextDoseDate
        self.repeatIntervalDays = max(1, repeatIntervalDays)
        self.isEnabled = isEnabled
        self.notificationIdentifier = "dose-reminder-\(id.uuidString)"
    }

    var doseUnit: DoseUnit {
        get { DoseUnit(rawValue: unitRawValue) ?? .milligrams }
        set { unitRawValue = newValue.rawValue }
    }

    var injectionSite: InjectionSite {
        get { InjectionSite(rawValue: injectionSiteRawValue) ?? .other }
        set { injectionSiteRawValue = newValue.rawValue }
    }

    var formattedDose: String {
        "\(doseAmount.peptideFormatted) \(unitRawValue)"
    }

    var snapshot: DoseReminderSnapshot {
        DoseReminderSnapshot(
            identifier: notificationIdentifier,
            peptideName: peptideName,
            doseAmount: doseAmount,
            unit: unitRawValue,
            injectionSite: injectionSiteRawValue,
            nextDoseDate: nextDoseDate,
            isEnabled: isEnabled
        )
    }
}

struct DoseReminderSnapshot: Sendable {
    let identifier: String
    let peptideName: String
    let doseAmount: Double
    let unit: String
    let injectionSite: String
    let nextDoseDate: Date
    let isEnabled: Bool

    var formattedDose: String {
        "\(doseAmount.peptideFormatted) \(unit)"
    }
}

@Model
final class TitrationPlan {
    @Attribute(.unique) var id: UUID
    var peptideName: String
    var startedOn: Date
    var startingDose: Double
    var targetDose: Double
    var stepIncrease: Double
    var escalationIntervalDays: Int
    var unitRawValue: String
    var isActive: Bool
    var notes: String

    init(
        peptideName: String,
        startedOn: Date,
        startingDose: Double,
        targetDose: Double,
        stepIncrease: Double,
        escalationIntervalDays: Int,
        unit: DoseUnit,
        isActive: Bool = true,
        notes: String = ""
    ) {
        self.id = UUID()
        self.peptideName = peptideName
        self.startedOn = startedOn
        self.startingDose = startingDose
        self.targetDose = targetDose
        self.stepIncrease = stepIncrease
        self.escalationIntervalDays = max(1, escalationIntervalDays)
        self.unitRawValue = unit.rawValue
        self.isActive = isActive
        self.notes = notes
    }

    var doseUnit: DoseUnit {
        get { DoseUnit(rawValue: unitRawValue) ?? .milligrams }
        set { unitRawValue = newValue.rawValue }
    }

    func phaseIndex(on date: Date = .now) -> Int {
        guard date > startedOn else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: startedOn, to: date).day ?? 0
        return max(0, days / escalationIntervalDays)
    }

    func currentDose(on date: Date = .now) -> Double {
        let dose = startingDose + (Double(phaseIndex(on: date)) * stepIncrease)
        return min(max(startingDose, dose), targetDose)
    }

    func nextStepDate(after date: Date = .now) -> Date? {
        guard currentDose(on: date) < targetDose else { return nil }
        let nextPhase = phaseIndex(on: date) + 1
        return Calendar.current.date(
            byAdding: .day,
            value: nextPhase * escalationIntervalDays,
            to: startedOn
        )
    }

    func projectedSteps(limit: Int = 24) -> [TitrationStep] {
        var steps: [TitrationStep] = []
        var dose = startingDose
        var index = 0

        while dose <= targetDose && index < limit {
            let date = Calendar.current.date(
                byAdding: .day,
                value: index * escalationIntervalDays,
                to: startedOn
            ) ?? startedOn

            steps.append(TitrationStep(index: index, date: date, dose: min(dose, targetDose)))

            if dose >= targetDose { break }
            dose += stepIncrease
            index += 1
        }

        if let last = steps.last, last.dose < targetDose, index < limit {
            let date = Calendar.current.date(
                byAdding: .day,
                value: (index + 1) * escalationIntervalDays,
                to: startedOn
            ) ?? startedOn
            steps.append(TitrationStep(index: index + 1, date: date, dose: targetDose))
        }

        return steps
    }
}

struct TitrationStep: Identifiable {
    let index: Int
    let date: Date
    let dose: Double

    var id: Int { index }
}

@Model
final class SideEffectEntry {
    @Attribute(.unique) var id: UUID
    var protocolIDString: String?
    var date: Date
    var symptom: String
    var severity: Int
    var notes: String

    init(protocolID: UUID? = nil, date: Date, symptom: String, severity: Int, notes: String = "") {
        self.id = UUID()
        self.protocolIDString = protocolID?.uuidString
        self.date = date
        self.symptom = symptom
        self.severity = min(max(severity, 1), 5)
        self.notes = notes
    }
}

@Model
final class BodyMeasurementEntry {
    @Attribute(.unique) var id: UUID
    var protocolIDString: String?
    var date: Date
    var weight: Double
    var waist: Double?
    var hip: Double?
    var chest: Double?
    var bodyFatPercentage: Double?
    var notes: String

    init(
        protocolID: UUID? = nil,
        date: Date,
        weight: Double,
        waist: Double? = nil,
        hip: Double? = nil,
        chest: Double? = nil,
        bodyFatPercentage: Double? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.protocolIDString = protocolID?.uuidString
        self.date = date
        self.weight = weight
        self.waist = waist
        self.hip = hip
        self.chest = chest
        self.bodyFatPercentage = bodyFatPercentage
        self.notes = notes
    }
}

@Model
final class ProgressPhotoEntry {
    @Attribute(.unique) var id: UUID
    var protocolIDString: String?
    var date: Date
    var caption: String
    @Attribute(.externalStorage) var imageData: Data?

    init(protocolID: UUID? = nil, date: Date, caption: String = "", imageData: Data?) {
        self.id = UUID()
        self.protocolIDString = protocolID?.uuidString
        self.date = date
        self.caption = caption
        self.imageData = imageData
    }
}

extension Double {
    var peptideFormatted: String {
        if rounded() == self {
            return String(format: "%.0f", self)
        }

        if abs(self) < 1 {
            return String(format: "%.3f", self)
        }

        return String(format: "%.2f", self)
    }
}
