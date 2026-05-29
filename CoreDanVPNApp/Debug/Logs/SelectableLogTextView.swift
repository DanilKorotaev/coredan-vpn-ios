import SwiftUI
import UIKit

struct SelectableLogTextView: UIViewRepresentable {
    let text: String
    let searchText: String
    @Binding var selectedMatchIndex: Int
    @Binding var matchCount: Int

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let attributed = highlightedText()
        if uiView.attributedText != attributed {
            uiView.attributedText = attributed
        }

        let ranges = matchedRanges(in: text, query: searchText)
        if matchCount != ranges.count {
            DispatchQueue.main.async { matchCount = ranges.count }
        }

        guard !ranges.isEmpty else {
            if selectedMatchIndex != 0 {
                DispatchQueue.main.async { selectedMatchIndex = 0 }
            }
            return
        }

        let index = min(max(selectedMatchIndex, 0), ranges.count - 1)
        if selectedMatchIndex != index {
            DispatchQueue.main.async { selectedMatchIndex = index }
        }
        let selectedRange = ranges[index]
        if uiView.selectedRange != selectedRange {
            uiView.selectedRange = selectedRange
            uiView.scrollRangeToVisible(selectedRange)
        }
    }

    private func highlightedText() -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [.font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular), .foregroundColor: UIColor.label]
        )
        let ranges = matchedRanges(in: text, query: searchText)
        for range in ranges {
            attributed.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.35), range: range)
        }
        if !ranges.isEmpty {
            let index = min(max(selectedMatchIndex, 0), ranges.count - 1)
            attributed.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.75), range: ranges[index])
        }
        return attributed
    }

    private func matchedRanges(in text: String, query: String) -> [NSRange] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let source = text as NSString
        var searchRange = NSRange(location: 0, length: source.length)
        var result: [NSRange] = []
        while true {
            let foundRange = source.range(of: query, options: [.caseInsensitive], range: searchRange)
            if foundRange.location == NSNotFound { break }
            result.append(foundRange)
            let nextLocation = foundRange.location + foundRange.length
            if nextLocation >= source.length { break }
            searchRange = NSRange(location: nextLocation, length: source.length - nextLocation)
        }
        return result
    }
}
