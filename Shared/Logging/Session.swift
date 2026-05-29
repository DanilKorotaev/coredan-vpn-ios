import Foundation

final class LogSession {
    static let shared = LogSession()

    let id: String
    let previousId: String?
    let startedAt: Date

    private init() {
        id = UUID().uuidString
        startedAt = Date()
        previousId = UserDefaultsService.shared.string(forKey: .loggerSessionId)
        UserDefaultsService.shared.set(id, forKey: .loggerSessionId)
    }
}
