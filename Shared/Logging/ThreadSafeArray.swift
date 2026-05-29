import Foundation

final class ThreadSafeArray<Element> {
    private var storage: [Element]
    private let lock = NSLock()

    init(_ storage: [Element]) {
        self.storage = storage
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    func append(_ element: Element) {
        lock.lock()
        storage.append(element)
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        storage.removeAll()
        lock.unlock()
    }

    func forEach(_ body: (Element) -> Void) {
        lock.lock()
        let snapshot = storage
        lock.unlock()
        snapshot.forEach(body)
    }
}
