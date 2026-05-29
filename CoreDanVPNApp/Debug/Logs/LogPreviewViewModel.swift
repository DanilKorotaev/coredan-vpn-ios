import Combine
import SwiftUI
import UIKit

protocol LogPreviewDetailsViewDelegate: AnyObject {
    func didCopyAllRequested(for item: LogPreviewItem)
    func didCopyCurlRequested(for item: LogPreviewItem)
    func didCopyBodyRequested(for item: LogPreviewItem)
    func canCopyCurl(for item: LogPreviewItem) -> Bool
    func canCopyBody(for item: LogPreviewItem) -> Bool
}

final class LogPreviewViewModel: ObservableObject, LogPreviewDetailsViewDelegate {
    private let fileURL: URL
    private var logs: [LogPreviewItem] = []
    private let filterRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "\\[[^]]+\\] ")
    private var cancellables: Set<AnyCancellable> = []

    private(set) var filters: [LogPreviewFilterItem] = []

    @Published private(set) var items: [LogPreviewItem] = []
    @Published var searchText = ""
    @Published var selectedFilters: Set<LogPreviewFilterItem> = [] {
        didSet { updateItems() }
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        bindSearch()
    }

    func didLoadView() {
        setup()
        updateItems()
    }

    func didShareLogsRequested() {
        guard let topViewController = TopViewController.current else { return }

        let activityItems: [Any]
        if searchText.isEmpty && selectedFilters.isEmpty {
            activityItems = [fileURL]
        } else {
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            let selectedFilterValues = selectedFilters.map(\.value).sorted().joined(separator: "+")
            let sharedFileName = [fileName,
                                  searchText.isEmpty ? nil : searchText,
                                  selectedFilterValues.isEmpty ? nil : selectedFilterValues]
                .compactMap { $0 }
                .joined(separator: "+")
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("\(sharedFileName).\(fileURL.pathExtension)")
            do {
                try items.map(\.message).joined(separator: "\n").write(to: tempURL, atomically: true, encoding: .utf8)
            } catch {
                return
            }
            activityItems = [tempURL]
        }

        let activityController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        topViewController.present(activityController, animated: true)
    }

    func didCopyAllRequested(for item: LogPreviewItem) {
        copyToPasteboard(item.message)
    }

    func didCopyCurlRequested(for item: LogPreviewItem) {
        guard let message = curlMessage(in: item.message) else { return }
        copyToPasteboard(message)
    }

    func didCopyBodyRequested(for item: LogPreviewItem) {
        guard let message = httpBody(in: item.message) else { return }
        copyToPasteboard(message)
    }

    func canCopyCurl(for item: LogPreviewItem) -> Bool {
        curlMessage(in: item.message) != nil
    }

    func canCopyBody(for item: LogPreviewItem) -> Bool {
        httpBody(in: item.message) != nil
    }

    private func copyToPasteboard(_ message: String) {
        UIPasteboard.general.string = message
    }

    private func curlMessage(in text: String) -> String? {
        guard let curlIndex = text.range(of: "curl", options: .caseInsensitive)?.lowerBound else { return nil }
        return String(text[curlIndex...])
    }

    private func httpBody(in text: String) -> String? {
        let marker = "HTTP Body: ["
        guard let markerRange = text.range(of: marker, options: .caseInsensitive) else { return nil }
        let bodyStart = markerRange.upperBound
        let tail = text[bodyStart...]
        guard let bodyEnd = tail.range(of: "\n]")?.lowerBound else { return nil }
        let body = String(tail[..<bodyEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? nil : body
    }

    private func updateItems() {
        let search = searchText.lowercased()
        let selectedFilterValues = selectedFilters.map(\.value)
        items = logs.filter { log in
            (selectedFilterValues.isEmpty || selectedFilterValues.contains(where: { log.message.contains($0) }))
                && (search.isEmpty || log.message.lowercased().contains(search))
        }
    }

    private func setup() {
        guard let logData = try? String(contentsOf: fileURL) else { return }
        let logLines = logData.components(separatedBy: .newlines)
        var rawLogs: [String] = []
        var currentLog: [String] = []
        var tags: [String] = []

        for line in logLines {
            filterRegex?.matches(in: line).forEach { tags.append($0) }
            if !currentLog.isEmpty,
               line.range(of: #"\d{4}-\d{2}-\d{2} \d{1,2}:\d{2}:\d{2}"#, options: .regularExpression) != nil {
                rawLogs.append(currentLog.joined(separator: "\n"))
                currentLog.removeAll()
            }
            currentLog.append(line)
        }
        if !currentLog.isEmpty {
            rawLogs.append(currentLog.joined(separator: "\n"))
        }

        filters = tags.group(by: { $0 })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
            .map { LogPreviewFilterItem.tag($0.0, count: $0.1) }

        logs = rawLogs.map { message in
            LogPreviewItem(message: message, preview: preview(from: message))
        }
    }

    private func bindSearch() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in self?.updateItems() }
            .store(in: &cancellables)
    }

    private func preview(from message: String) -> String {
        let lines = message.split(separator: "\n", omittingEmptySubsequences: false).prefix(3)
        let text = lines.joined(separator: "\n")
        let maxLength = 500
        if text.count <= maxLength { return text }
        return String(text.prefix(maxLength)) + "..."
    }
}
