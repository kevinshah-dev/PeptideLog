import SwiftData
import SwiftUI

@main
struct ProtocolsApp: App {
    private let modelContainer = ModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(modelContainer)
    }
}
