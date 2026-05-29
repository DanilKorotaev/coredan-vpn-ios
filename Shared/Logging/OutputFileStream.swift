import Foundation

final class OutputFileStream {
    enum OutputStreamError: Error {
        case invalidPath(String)
        case unableToOpen(String)
        case unableToWrite(String)
        case unableToCreate(String)
    }

    private var fileHandle: FileHandle?
    let fileURL: URL

    init(fileURL: URL) throws {
        self.fileURL = fileURL
        let path = fileURL.path
        guard !path.isEmpty else {
            throw OutputStreamError.invalidPath(path)
        }
    }

    func create() throws {
        let path = fileURL.path
        if FileManager.default.fileExists(atPath: path) {
            throw OutputStreamError.unableToCreate(path)
        }
        guard FileManager.default.createFile(atPath: path, contents: nil) else {
            throw OutputStreamError.unableToCreate(path)
        }
    }

    func open() throws {
        guard fileHandle == nil else { return }
        do {
            fileHandle = try FileHandle(forWritingTo: fileURL)
            _ = try? fileHandle?.seekToEnd()
        } catch {
            throw OutputStreamError.unableToOpen(fileURL.path)
        }
    }

    func write(_ string: String) throws {
        guard !string.isEmpty, let data = string.data(using: .utf8) else { return }
        guard let fileHandle else { return }
        try fileHandle.write(contentsOf: data)
    }

    func close() {
        fileHandle?.synchronizeFile()
        fileHandle?.closeFile()
        fileHandle = nil
    }
}
