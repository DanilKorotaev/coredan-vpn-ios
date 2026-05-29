import Foundation
import SwiftUI

extension UserDefaultsInspectorSettingsView {
    final class ViewModel: ObservableObject {
        @Published var isLoggingEnabled: Bool {
            didSet {
                tagsProvider.set(isEnabled: isLoggingEnabled, for: .userDefaultsService)
            }
        }

        @Published var isVerboseLoggingEnabled: Bool {
            didSet {
                settings.isVerboseLoggingEnabled = isVerboseLoggingEnabled
            }
        }

        @Published var ignoredKeys: [String] {
            didSet {
                settings.ignoredAddOrUpdateKeys = ignoredKeys
            }
        }

        @Published var draftIgnoredKey: String = ""

        private let settings: UserDefaultsInspectorSettingsDescription
        private let tagsProvider: LoggerTagsProviderDescription

        var canAddDraftIgnoredKey: Bool {
            let normalized = normalizedKey(draftIgnoredKey)
            return !normalized.isEmpty && !ignoredKeys.contains(normalized)
        }

        init(
            settings: UserDefaultsInspectorSettingsDescription = UserDefaultsInspectorSettings.shared,
            tagsProvider: LoggerTagsProviderDescription = AppLoggerTagsProvider.shared
        ) {
            self.settings = settings
            self.tagsProvider = tagsProvider
            isLoggingEnabled = tagsProvider.isEnabled(tag: .userDefaultsService)
            isVerboseLoggingEnabled = settings.isVerboseLoggingEnabled
            ignoredKeys = settings.ignoredAddOrUpdateKeys.sorted()
        }

        func addDraftIgnoredKey() {
            let key = normalizedKey(draftIgnoredKey)
            guard !key.isEmpty, !ignoredKeys.contains(key) else { return }
            ignoredKeys.append(key)
            ignoredKeys.sort()
            draftIgnoredKey = ""
        }

        func deleteIgnoredKeys(at offsets: IndexSet) {
            ignoredKeys.remove(atOffsets: offsets)
        }

        private func normalizedKey(_ key: String) -> String {
            key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
