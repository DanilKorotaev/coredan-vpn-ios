import Foundation

/// Bridges Libbox callbacks (sync) to Swift concurrency.
func libboxRunBlocking<T>(_ block: @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<T, Error>!
    Task.detached(priority: .userInitiated) {
        do {
            result = .success(try await block())
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()
    return try result.get()
}

func libboxRunBlocking<T>(_ block: @escaping () async -> T) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var value: T!
    Task.detached(priority: .userInitiated) {
        value = await block()
        semaphore.signal()
    }
    semaphore.wait()
    return value
}
