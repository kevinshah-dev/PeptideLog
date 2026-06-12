import Foundation

enum MedicalDisclaimer {
    static let copy = "Protocols is an informational tracking tool only. Nothing in this app constitutes medical advice. Always consult a licensed healthcare provider before starting, changing, or stopping any GLP or medication protocol."
}

struct PeptideInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let aliases: String
    let category: String
    let cadence: String
    let summary: String
    let overview: String
    let mechanism: String
    let dosingProtocols: String
    let reconstitution: String
    let storage: String
}

enum PeptideLibrary {
    static let items: [PeptideInfo] = [
        PeptideInfo(
            id: "semaglutide",
            name: "Semaglutide",
            aliases: "Ozempic / Wegovy / GLP-1",
            category: "GLP-1 receptor agonist",
            cadence: "Weekly injection",
            summary: "Weight loss and blood sugar support through GLP-1 receptor activity.",
            overview: "Semaglutide is a GLP-1 receptor agonist used in prescription products for type 2 diabetes management and chronic weight management. It is typically administered once weekly and is intended to be managed under clinician supervision.",
            mechanism: "GLP-1 receptor activation can increase glucose-dependent insulin secretion, reduce glucagon secretion, slow gastric emptying, and increase satiety signaling. These effects can support improved blood sugar control and reduced appetite.",
            dosingProtocols: "Common clinical protocols start with a low weekly dose and escalate gradually, often over 4-week intervals, to improve tolerability. Product-specific schedules and maximum doses vary by indication and prescribing guidance.",
            reconstitution: "Commercial semaglutide pens are supplied ready to use. Compounded or vial-based preparations may require bacteriostatic water or another specified diluent; concentration calculations should be verified by a licensed healthcare professional.",
            storage: "Commercial products are commonly refrigerated before first use and may allow limited room-temperature storage after first use. Follow the product label or pharmacy instructions exactly."
        ),
        PeptideInfo(
            id: "retatrutide",
            name: "Retatrutide",
            aliases: "Research-stage GLP / GIP / glucagon agonist",
            category: "GLP-1 / GIP / glucagon triple agonist",
            cadence: "Weekly injection in studies",
            summary: "A research-stage triple agonist associated with aggressive weight-loss profiles in clinical studies.",
            overview: "Retatrutide is an investigational medication being studied for obesity and metabolic disease. It is not a broadly approved consumer medication, and public dosing standards are not established outside clinical research.",
            mechanism: "Retatrutide is designed to activate GLP-1, GIP, and glucagon receptors. The combined pathway approach is being studied for appetite regulation, energy balance, glucose metabolism, and weight reduction.",
            dosingProtocols: "Research protocols have evaluated weekly injections with staged escalation. Dose amounts, escalation speed, and tolerability rules are study-specific and should not be treated as a self-directed protocol.",
            reconstitution: "Research vials may be lyophilized and require careful reconstitution with a specified diluent. Sterility, concentration, and handling should be verified before any use in a supervised setting.",
            storage: "Lyophilized research material is commonly stored cold and protected from light. Reconstituted material is typically refrigerated and used within a limited window defined by the supplier or study protocol."
        ),
        PeptideInfo(
            id: "glp-1",
            name: "GLP-1",
            aliases: "Class tracker",
            category: "GLP medication protocol",
            cadence: "Clinician-directed schedule",
            summary: "A generic tracking option for GLP-1 medication protocols.",
            overview: "Use this entry when you want to track a GLP-1 protocol without choosing a molecule-specific or brand-specific profile. Exact use, schedule, and goals should come from the prescribing clinician or pharmacy instructions.",
            mechanism: "GLP-1 receptor activity can influence glucose-dependent insulin secretion, glucagon signaling, gastric emptying, and satiety. The details vary by medication and formulation.",
            dosingProtocols: "GLP-1 protocols commonly use gradual titration to support tolerability, but dose amounts, timing, and maximum doses depend on the exact medication and indication.",
            reconstitution: "Follow the product label, pharmacy instructions, or prescriber guidance. Commercial pens may be ready to use, while vial-based preparations may have specific concentration and handling requirements.",
            storage: "Follow the product label or pharmacy instructions exactly, including refrigeration, room-temperature limits, and discard timing."
        ),
        PeptideInfo(
            id: "glp-3",
            name: "GLP-3",
            aliases: "Custom GLP tracker",
            category: "Custom GLP protocol",
            cadence: "Clinician-directed schedule",
            summary: "A flexible tracking option for GLP-3-labeled protocols.",
            overview: "Use this entry when your plan or clinician uses a GLP-3 label and you want a dedicated place to track doses, titration, effects, and progress. Confirm the exact medication, concentration, and terminology with a licensed healthcare professional.",
            mechanism: "Mechanism details depend on the exact product or protocol being tracked. Use the notes field to capture clinician-provided details that are specific to your plan.",
            dosingProtocols: "Follow the schedule, dose, escalation, and hold rules provided by the supervising clinician or pharmacy. Do not infer a protocol from another GLP medication.",
            reconstitution: "Follow the product-specific instructions provided by the pharmacy, manufacturer, or supervising clinician.",
            storage: "Follow the product-specific storage instructions, including refrigeration, light protection, and discard timing."
        )
    ]

    static var peptideNames: [String] {
        items.map(\.name)
    }

    static var defaultPeptideName: String {
        peptideNames.first ?? "Semaglutide"
    }

    static func supportedPeptideName(_ preferredPeptideName: String?) -> String {
        guard let preferredPeptideName,
              isSupportedPeptideName(preferredPeptideName) else {
            return defaultPeptideName
        }

        return preferredPeptideName
    }

    static func isSupportedPeptideName(_ peptideName: String) -> Bool {
        peptideNames.contains(peptideName)
    }

    static func orderedItems(preferredPeptideName: String?) -> [PeptideInfo] {
        guard let preferredPeptideName,
              let preferredItem = items.first(where: { $0.name == preferredPeptideName }) else {
            return items
        }

        return [preferredItem] + items.filter { $0.id != preferredItem.id }
    }

    static func orderedPeptideNames(preferredPeptideName: String?) -> [String] {
        orderedItems(preferredPeptideName: preferredPeptideName).map(\.name)
    }
}
