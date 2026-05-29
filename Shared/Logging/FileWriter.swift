import Foundation
import UIKit

class FileWriter {
    let queue: DispatchQueue
    private let fileManager = FileManager.default
    private let url: URL
    private var outputStream: OutputFileStream?

    init(url: URL) {
        self.url = url
        queue = DispatchQueue(label: "com.coredan.CoreDanVPN.FileLogger.serial.queue")
        subscribeToNotifications()
    }

    func write(_ text: String) {
        queue.async { [weak self] in
            guard let self else { return }
            if !fileManager.fileExists(atPath: url.path) {
                start(file: url)
            } else if outputStream == nil {
                open(file: url)
            }
            try? outputStream?.write(text)
        }
    }

    @objc
    func close() {
        queue.async { [weak self] in
            self?.finish(file: self?.url)
        }
    }

    private func start(file: URL) {
        do {
            outputStream = try OutputFileStream(fileURL: file)
            try outputStream?.create()
            try outputStream?.open()
        } catch {
            #if DEBUG
            print("[CoreDanVPN FileLogger] start error: \(error)")
            #endif
        }
    }

    private func open(file: URL) {
        do {
            outputStream = try OutputFileStream(fileURL: file)
            try outputStream?.open()
        } catch {
            #if DEBUG
            print("[CoreDanVPN FileLogger] open error: \(error)")
            #endif
        }
    }

    private func finish(file: URL?) {
        outputStream?.close()
        outputStream = nil
    }

    private func subscribeToNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(close),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(close),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
}
