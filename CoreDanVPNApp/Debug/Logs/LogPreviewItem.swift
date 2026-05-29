import Foundation

struct LogPreviewItem: Identifiable {
    let message: String
    let preview: String
    let id = UUID()

    init(message: String, preview: String? = nil) {
        self.message = message
        self.preview = preview ?? message
    }
}
