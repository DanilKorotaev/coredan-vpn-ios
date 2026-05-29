import SwiftUI

enum LogsMenuScreen: String, CaseIterable, Identifiable {
    case files
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .files: return "Files"
        case .settings: return "Settings"
        }
    }
}

struct LogsMenuView: View {
    var body: some View {
        List(LogsMenuScreen.allCases) { screen in
            NavigationLink(screen.title) {
                switch screen {
                case .files:
                    LogFilesView()
                case .settings:
                    LogSettingsView()
                }
            }
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
    }
}
