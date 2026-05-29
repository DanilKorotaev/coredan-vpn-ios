import Foundation

enum LogLevel: String, CustomStringConvertible {
    case info
    case warning
    case error
    case nonFatal
    case critical

    var description: String { rawValue.uppercased() }

    var emoji: String {
        switch self {
        case .info: return "✅"
        case .warning: return "⚠️"
        case .error: return "🆘"
        case .nonFatal: return "❗️"
        case .critical: return "❌"
        }
    }
}

enum LogBuildLevel {
    case debug
    case release
}

protocol Logger {
    func log(_ message: Any?, level: LogLevel, buildLevel: LogBuildLevel)
    func tag(_ tag: LoggerTag) -> Logger
}

extension Logger {
    func log(_ message: Any?, level: LogLevel = .info, buildLevel: LogBuildLevel = .debug) {
        log(message, level: level, buildLevel: buildLevel)
    }

    func tag(_ tag: LoggerTag) -> Logger { self }

    func releaseInfo(_ message: Any?) {
        log(message, level: .info, buildLevel: .release)
    }

    func releaseError(_ message: Any?) {
        log(message, level: .error, buildLevel: .release)
    }

    func debugError(_ message: Any?) {
        log(message, level: .error, buildLevel: .debug)
    }

    func debugInfo(_ message: Any?) {
        log(message, level: .info, buildLevel: .debug)
    }

    func warning(_ message: Any?, buildLevel: LogBuildLevel = .debug) {
        log(message, level: .warning, buildLevel: buildLevel)
    }
}

func makeLogger(tag: LoggerTag, config: LoggerConfig = .shared) -> Logger {
    makeLogger(tags: [tag], config: config)
}

func makeLogger(tags: [LoggerTag], config: LoggerConfig = .shared) -> Logger {
    LoggerImpl(tags: tags, config: config)
}

let commonLogger: Logger = makeLogger(tag: .common)

private final class LoggerImpl: Logger, @unchecked Sendable {
    private let tags: [LoggerTag]
    private let tagsText: String
    private let config: LoggerConfig

    init(tags: [LoggerTag], config: LoggerConfig) {
        self.tags = tags
        tagsText = tags.map { "[\($0.rawValue)]" }.joined(separator: " ")
        self.config = config
    }

    func log(_ message: Any?, level: LogLevel, buildLevel: LogBuildLevel) {
        let isDebugLogger = config.settings.isDebugLogger
        guard let message,
              !tags.contains(where: config.excludedTagProvider.excludedTags.contains)
                || level == .nonFatal || level == .critical,
              !(buildLevel == .debug && !isDebugLogger)
        else { return }

        let targetMessage = prepare(message, level: level, isDebugLogger: isDebugLogger)
        activeBackends().forEach { $0.log(targetMessage, level: level, buildLevel: buildLevel) }
    }

    func tag(_ tag: LoggerTag) -> Logger {
        LoggerImpl(tags: tags + [tag], config: config)
    }

    private func activeBackends() -> [Logger] {
        var backends: [Logger] = []
        if config.settings.isDebugLogger {
            backends.append(ConsoleLogger())
        }
        if config.settings.isFileLoggerEnabled {
            backends.append(FileLogger.shared)
        }
        return backends
    }

    private func prepare(_ message: Any, level: LogLevel, isDebugLogger: Bool) -> Any {
        if let error = message as? Error {
            return prepareError(from: error as NSError, level: level)
        }
        return buildMessage(from: "\(message)", level: level, isDebugLogger: isDebugLogger)
    }

    private func buildMessage(from message: CustomStringConvertible, level: LogLevel, isDebugLogger: Bool) -> String {
        let targetMessage: String
        if isDebugLogger {
            if let string = message as? String {
                targetMessage = string
            } else if let debugConvertable = message as? CustomDebugStringConvertible {
                targetMessage = debugConvertable.debugDescription
            } else {
                targetMessage = message.description
            }
        } else {
            targetMessage = message.description
        }
        return "[\(level.emoji) \(level.description)] \(tagsText) \(targetMessage)"
    }

    private func prepareError(from error: NSError, level: LogLevel) -> NSError {
        let description = "\(level.rawValue) \(tagsText) \(error.localizedDescription)"
        var userInfo = error.userInfo
        userInfo["messageTag"] = tagsText
        userInfo[NSLocalizedDescriptionKey] = description
        return NSError(domain: error.domain, code: error.code, userInfo: userInfo)
    }
}
