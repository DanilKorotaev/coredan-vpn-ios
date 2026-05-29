import SwiftUI

struct LogFileItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

final class LogFilesViewModel: ObservableObject {
    @Published var items: [LogFileItem] = LogFilesProvider.shared.logFileUrls.map(LogFileItem.init)

    func reload() {
        items = LogFilesProvider.shared.logFileUrls.map(LogFileItem.init)
    }
}

struct LogFilesView: View {
    @StateObject private var viewModel = LogFilesViewModel()

    var body: some View {
        List(viewModel.items) { item in
            NavigationLink {
                LogPreviewView(viewModel: LogPreviewViewModel(fileURL: item.url))
            } label: {
                Text(item.url.lastPathComponent)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .navigationTitle("Files")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.reload() }
        .refreshable { viewModel.reload() }
    }
}
