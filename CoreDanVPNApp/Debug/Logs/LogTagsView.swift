import SwiftUI

final class LoggerTagViewItem: Identifiable {
    let tag: LoggerTag?
    let title: String
    var isEnabled: Bool

    var id: String { tag?.rawValue ?? "All" }
    var isAll: Bool { tag == nil }

    init(tag: LoggerTag?, title: String, isEnabled: Bool) {
        self.tag = tag
        self.title = title
        self.isEnabled = isEnabled
    }
}

final class LogTagsViewModel: ObservableObject {
    private let tagsProvider: LoggerTagsProviderDescription
    private let allItem: LoggerTagViewItem
    private let tags: [LoggerTagViewItem]

    @Published var items: [LoggerTagViewItem] = []
    @Published var searchText = "" {
        didSet { updateItems() }
    }

    init(tagsProvider: LoggerTagsProviderDescription) {
        self.tagsProvider = tagsProvider
        let tagItems = tagsProvider.tags.map {
            LoggerTagViewItem(tag: $0, title: $0.rawValue, isEnabled: tagsProvider.isEnabled(tag: $0))
        }
        tags = tagItems
        allItem = LoggerTagViewItem(tag: nil, title: "All", isEnabled: tagItems.allSatisfy(\.isEnabled))
    }

    func didLoadView() {
        syncAllItemState()
        updateItems()
    }

    func set(enabled: Bool, for item: LoggerTagViewItem) {
        if item.isAll {
            allItem.isEnabled = enabled
            tags.forEach { $0.isEnabled = enabled }
            tagsProvider.setAll(isEnabled: enabled)
            updateItems()
            return
        }
        item.isEnabled = enabled
        if let tag = item.tag {
            tagsProvider.set(isEnabled: enabled, for: tag)
        }
        syncAllItemState()
        updateItems()
    }

    func resetToDefaults() {
        tagsProvider.resetToDefaults()
        tags.forEach { item in
            guard let tag = item.tag else { return }
            item.isEnabled = tagsProvider.isEnabled(tag: tag)
        }
        syncAllItemState()
        updateItems()
    }

    private func updateItems() {
        let filtered: [LoggerTagViewItem]
        if searchText.isEmpty {
            filtered = tags
        } else {
            let q = searchText.lowercased()
            filtered = tags.filter { $0.title.lowercased().contains(q) }
        }
        items = [allItem] + filtered
    }

    private func syncAllItemState() {
        allItem.isEnabled = tags.allSatisfy(\.isEnabled)
    }
}

struct LogTagsView: View {
    @StateObject var viewModel: LogTagsViewModel

    var body: some View {
        List(viewModel.items) { item in
            Toggle(item.title, isOn: Binding(
                get: { item.isEnabled },
                set: { viewModel.set(enabled: $0, for: item) }
            ))
        }
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle("Tags")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") { viewModel.resetToDefaults() }
            }
        }
        .onAppear { viewModel.didLoadView() }
    }
}
