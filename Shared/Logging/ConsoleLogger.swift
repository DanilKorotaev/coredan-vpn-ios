import Foundation
import os

final class ConsoleLogger: Logger, @unchecked Sendable {
    func log(_ message: Any?, level: LogLevel, buildLevel: LogBuildLevel) {
        guard let message else { return }
        os_log("%@", prepare(message))
    }

    private func prepare(_ message: Any) -> String {
        if let error = message as? Error {
            return prepareError(error)
        }
        return "\(message)"
    }

    private func prepareError(_ error: Error) -> String {
        let nsError = error as NSError
        var result: [String] = []
        result.append("Code : \(nsError.code)")
        result.append("Description : \(nsError.localizedDescription)")
        if let reason = nsError.localizedFailureReason {
            result.append("Reason : \(reason)")
        }
        if let suggestion = nsError.localizedRecoverySuggestion {
            result.append("Suggestion : \(suggestion)")
        }
        result.append("UserInfo : \(nsError.userInfo.description)")
        return result.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
