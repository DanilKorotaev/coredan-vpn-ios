import Foundation

enum LogPreviewFilterItem: Hashable {
    case tag(_ text: String, count: Int)
}

extension LogPreviewFilterItem {
    var text: String {
        switch self {
        case let .tag(text, count):
            return "\(text) \(count)"
        }
    }

    var value: String {
        switch self {
        case let .tag(text, _):
            return text
        }
    }
}
