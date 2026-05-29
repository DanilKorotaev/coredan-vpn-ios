import SwiftUI
import UIKit

struct LogPreviewDetailsView: View {
    let item: LogPreviewItem
    let delegate: LogPreviewDetailsViewDelegate
    @State private var searchText: String
    @State private var currentMatchIndex = 0
    @State private var matchCount = 0
    @State private var isKeyboardVisible = false

    init(item: LogPreviewItem, delegate: LogPreviewDetailsViewDelegate, initialSearchText: String) {
        self.item = item
        self.delegate = delegate
        _searchText = State(initialValue: initialSearchText)
    }

    var body: some View {
        SelectableLogTextView(
            text: item.message,
            searchText: searchText,
            selectedMatchIndex: $currentMatchIndex,
            matchCount: $matchCount
        )
        .background(SearchTextFieldConfigurator())
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Copy all") { delegate.didCopyAllRequested(for: item) }
                    if delegate.canCopyCurl(for: item) {
                        Button("Copy cURL") { delegate.didCopyCurlRequested(for: item) }
                    }
                    if delegate.canCopyBody(for: item) {
                        Button("Copy body") { delegate.didCopyBodyRequested(for: item) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isKeyboardVisible && !searchText.isEmpty {
                HStack(spacing: 24) {
                    Button { goToPreviousMatch() } label: { Image(systemName: "chevron.up") }
                        .disabled(matchCount == 0)
                    Text(matchCounterText)
                        .foregroundStyle(.secondary)
                    Button { goToNextMatch() } label: { Image(systemName: "chevron.down") }
                        .disabled(matchCount == 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
        .onChange(of: searchText) { _, _ in currentMatchIndex = 0 }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    private var matchCounterText: String {
        guard matchCount > 0 else { return "0/0" }
        return "\(currentMatchIndex + 1)/\(matchCount)"
    }

    private func goToPreviousMatch() {
        guard matchCount > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matchCount) % matchCount
    }

    private func goToNextMatch() {
        guard matchCount > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matchCount
    }
}
