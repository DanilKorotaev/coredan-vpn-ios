import Foundation

extension NSRegularExpression {
    func matches(in string: String) -> [String] {
        let range = NSRange(location: 0, length: string.utf16.count)
        return matches(in: string, options: [], range: range).compactMap { match in
            Range(match.range, in: string).map { String(string[$0]) }
        }
    }
}
