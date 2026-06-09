import Foundation

enum MedicalDisclaimer {
    static let copy = "Protocols is an informational tracking tool only. Nothing in this app constitutes medical advice. Always consult a licensed healthcare provider before starting, changing, or stopping any peptide or medication protocol."
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
            aliases: "Ozempic / Wegovy",
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
            aliases: "Research peptide",
            category: "GLP-1 / GIP / glucagon triple agonist",
            cadence: "Weekly injection in studies",
            summary: "A research-stage triple agonist associated with aggressive weight-loss profiles in clinical studies.",
            overview: "Retatrutide is an investigational peptide being studied for obesity and metabolic disease. It is not a broadly approved consumer medication, and public dosing standards are not established outside clinical research.",
            mechanism: "Retatrutide is designed to activate GLP-1, GIP, and glucagon receptors. The combined pathway approach is being studied for appetite regulation, energy balance, glucose metabolism, and weight reduction.",
            dosingProtocols: "Research protocols have evaluated weekly injections with staged escalation. Dose amounts, escalation speed, and tolerability rules are study-specific and should not be treated as a self-directed protocol.",
            reconstitution: "Research vials may be lyophilized and require careful reconstitution with a specified diluent. Sterility, concentration, and handling should be verified before any use in a supervised setting.",
            storage: "Lyophilized research material is commonly stored cold and protected from light. Reconstituted material is typically refrigerated and used within a limited window defined by the supplier or study protocol."
        ),
        PeptideInfo(
            id: "ghk-cu",
            name: "GHK-CU",
            aliases: "Copper peptide",
            category: "Copper-binding peptide",
            cadence: "Topical or subcutaneous",
            summary: "Used in skin, hair, and anti-inflammatory contexts with topical and injectable protocols.",
            overview: "GHK-CU is a copper peptide commonly discussed in skin health, hair care, wound support, and inflammation-related wellness contexts. It appears in both cosmetic and research-oriented preparations.",
            mechanism: "GHK-CU binds copper ions and is associated with signaling involved in collagen support, tissue remodeling, antioxidant pathways, and skin barrier appearance. Effects and quality vary by formulation and route.",
            dosingProtocols: "Topical protocols are usually product-specific. Subcutaneous protocols vary widely in wellness settings and should be reviewed with a qualified clinician, especially when combined with other therapies.",
            reconstitution: "Lyophilized injectable preparations may require bacteriostatic water or another sterile diluent. Avoid shaking vigorously; gentle swirling is typically preferred for peptide handling.",
            storage: "Topicals follow product-label storage. Lyophilized vials are commonly kept refrigerated or frozen depending on supplier guidance; reconstituted vials are generally refrigerated and handled sterilely."
        ),
        PeptideInfo(
            id: "bpc-157",
            name: "BPC-157",
            aliases: "Body protection compound",
            category: "Research peptide",
            cadence: "Subcutaneous or oral",
            summary: "Often discussed for gut healing and injury recovery, with limited regulated clinical guidance.",
            overview: "BPC-157 is a synthetic peptide fragment discussed in gut health, soft-tissue injury, and recovery communities. It lacks the standardized prescribing framework of approved medications in many markets.",
            mechanism: "Proposed mechanisms include local tissue signaling, angiogenesis-related pathways, nitric oxide modulation, and inflammatory response effects. Much of the discussion relies on preclinical or nonstandard evidence.",
            dosingProtocols: "Subcutaneous and oral protocols vary substantially in nonclinical settings. Because there is no universal approved protocol, dose, route, and duration should be evaluated with a licensed healthcare provider.",
            reconstitution: "Injectable vials may be supplied lyophilized and reconstituted with sterile diluent. Concentration math, sterile handling, and injection technique should be verified before use.",
            storage: "Lyophilized material is commonly stored cold and dry. Reconstituted injectable material is generally refrigerated, protected from contamination, and discarded according to supplier or clinician guidance."
        )
    ]

    static var peptideNames: [String] {
        items.map(\.name)
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
