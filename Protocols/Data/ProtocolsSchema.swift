import SwiftData

enum ProtocolsSchema {
    static let models: [any PersistentModel.Type] = [
        PeptideProtocol.self,
        DoseLogEntry.self,
        DoseReminder.self,
        TitrationPlan.self,
        SideEffectEntry.self,
        BodyMeasurementEntry.self,
        ProgressPhotoEntry.self
    ]

    static let schema = Schema(models)
}

enum ModelContainerFactory {
    static func make(inMemory: Bool = false) -> ModelContainer {
        do {
            let configuration = ModelConfiguration(
                schema: ProtocolsSchema.schema,
                isStoredInMemoryOnly: inMemory
            )

            return try ModelContainer(
                for: ProtocolsSchema.schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Unable to create Protocols model container: \(error)")
        }
    }
}
