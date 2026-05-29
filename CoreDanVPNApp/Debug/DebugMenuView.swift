import SwiftUI

enum DebugMenuScreen: String, CaseIterable, Identifiable {
    case logs
    case userDefaults

    var id: String { rawValue }

    var title: String {
        switch self {
        case .logs: return "Logs"
        case .userDefaults: return "UserDefaults"
        }
    }
}

struct DebugMenuView: View {
    var body: some View {
        List(DebugMenuScreen.allCases) { screen in
            NavigationLink(screen.title) {
                destination(for: screen)
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func destination(for screen: DebugMenuScreen) -> some View {
        switch screen {
        case .logs:
            LogsMenuView()
        case .userDefaults:
            UserDefaultsListView()
        }
    }
}
