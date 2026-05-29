import SwiftUI

@main
struct CoreDanVPNApp: App {
    init() {
        LoggingBootstrap.startIfNeeded()
        UserDefaultsService.shared = UserDefaultsService(settings: UserDefaultsInspectorSettings.shared)
        UserDefaultsInspectorLogger.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ProfilesView()
        }
    }
}
