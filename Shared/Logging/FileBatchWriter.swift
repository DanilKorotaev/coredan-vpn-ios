import Foundation

final class FileBatchWriter: FileWriter {
    private let batchCapacity: Int
    private var batch: [String] = []

    init(url: URL, batchCapacity: Int) {
        self.batchCapacity = max(1, batchCapacity)
        super.init(url: url)
    }

    override func write(_ text: String) {
        queue.async { [weak self] in
            guard let self else { return }
            batch.append(text)
            if batch.count >= batchCapacity {
                flushOnQueue()
            }
        }
    }

    override func close() {
        queue.async { [weak self] in
            self?.performClose()
        }
    }

    private func performClose() {
        flushOnQueue()
        super.close()
    }

    private func flushOnQueue() {
        let pending = batch
        batch.removeAll()
        for line in pending {
            superWrite(line)
        }
    }

    private func superWrite(_ text: String) {
        super.write(text)
    }
}
