import Foundation

/// App Group directories for Libbox (working/cache) inside the packet tunnel extension.
enum TunnelPaths {
    static var sharedDirectory: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier) else {
            // Never fatalError in production — it surfaces as “Share with Developer”.
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("CoreDanVPN-MissingAppGroup", isDirectory: true)
        }
        return url
    }

    static var cacheDirectory: URL {
        sharedDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
    }

    static var workingDirectory: URL {
        cacheDirectory.appendingPathComponent("Working", isDirectory: true)
    }

    static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
