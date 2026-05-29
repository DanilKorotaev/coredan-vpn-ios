import SwiftUI

struct LogPreviewView: View {
    @StateObject var viewModel: LogPreviewViewModel

    var body: some View {
        List(viewModel.items) { item in
            NavigationLink {
                LogPreviewDetailsView(
                    item: item,
                    delegate: viewModel,
                    initialSearchText: viewModel.searchText
                )
            } label: {
                Text(item.preview)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
            }
            .contextMenu {
                Button("Copy all") { viewModel.didCopyAllRequested(for: item) }
                if viewModel.canCopyCurl(for: item) {
                    Button("Copy cURL") { viewModel.didCopyCurlRequested(for: item) }
                }
                if viewModel.canCopyBody(for: item) {
                    Button("Copy body") { viewModel.didCopyBodyRequested(for: item) }
                }
            }
        }
        .onAppear { viewModel.didLoadView() }
        .background(SearchTextFieldConfigurator())
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                // use activity sheet
                Button { viewModel.didShareLogsRequested() } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Menu {
                    Button {
                        viewModel.selectedFilters = []
                    } label: {
                        if viewModel.selectedFilters.isEmpty {
                            Label("All", systemImage: "checkmark")
                        } else {
                            Text("All")
                        }
                    }
                    ForEach(viewModel.filters, id: \.self) { filter in
                        Button {
                            if viewModel.selectedFilters.contains(filter) {
                                viewModel.selectedFilters.remove(filter)
                            } else {
                                viewModel.selectedFilters.insert(filter)
                            }
                        } label: {
                            if viewModel.selectedFilters.contains(filter) {
                                Label(filter.text, systemImage: "checkmark")
                            } else {
                                Text(filter.text)
                            }
                        }
                    }
                } label: {
                    Text(filterTitle)
                }
            }
        }
    }

    private var filterTitle: String {
        if viewModel.selectedFilters.isEmpty { return "All" }
        return "Tags: \(viewModel.selectedFilters.count)"
    }
}
