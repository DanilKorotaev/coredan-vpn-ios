import SwiftUI

final class LogSettingsViewModel: ObservableObject {
    private let settings = AppLoggerSettings.shared
    let filesCapabilityRange = 1 ... 100

    @Published var isFileLoggerEnabled: Bool {
        didSet {
            settings.isFileLoggerEnabled = isFileLoggerEnabled
            if isFileLoggerEnabled {
                FileLogger.shared.resetWriter()
            }
        }
    }

    @Published var isDebugLogger: Bool {
        didSet { settings.isDebugLogger = isDebugLogger }
    }

    @Published var isVerboseLog: Bool {
        didSet { settings.isVerboseLog = isVerboseLog }
    }

    @Published var fileStorageCapability: Int {
        didSet {
            do {
                try LogFilesProvider.shared.setMaxFileToStorage(fileStorageCapability)
            } catch {
                fileStorageCapability = oldValue
            }
        }
    }

    init() {
        isFileLoggerEnabled = settings.isFileLoggerEnabled
        isDebugLogger = settings.isDebugLogger
        isVerboseLog = settings.isVerboseLog
        fileStorageCapability = LogFilesProvider.shared.maxFileToStorage
    }
}

struct LogSettingsView: View {
    @StateObject private var viewModel = LogSettingsViewModel()

    var body: some View {
        Form {
            Toggle("Logging into file", isOn: $viewModel.isFileLoggerEnabled)
            Toggle("Logging into console", isOn: $viewModel.isDebugLogger)
            Toggle("Verbose logs (network cURL + body)", isOn: $viewModel.isVerboseLog)

            Picker(selection: $viewModel.fileStorageCapability) {
                ForEach(viewModel.filesCapabilityRange, id: \.self) { value in
                    Text("\(value)")
                }
            } label: {
                Text("File storage capability")
            }

            NavigationLink("Tags") {
                LogTagsView(viewModel: LogTagsViewModel(tagsProvider: AppLoggerTagsProvider.shared))
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
