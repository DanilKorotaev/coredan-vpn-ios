import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("Разработчик") {
                NavigationLink("Debug menu") {
                    DebugMenuView()
                }
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
    }
}
