//
//  UserDefaultsDetailView.swift
//  KnowledgeBaseApp
//
//  Created by danil.korotaev on 15.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import SwiftUI
import UIKit


struct UserDefaultsDetailView: View {
    @SwiftUI.Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ViewModel
    @State private var isPresentingEditValue = false
    @State private var valueTextHeight: CGFloat = 25

    init(key: String) {
        _viewModel = StateObject(wrappedValue: ViewModel(key: key))
    }

    var body: some View {
        Form {
            infoSection
            valueSection
        }
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                optionsMenu
            }
        }
        .kbErrorAlert(error: $viewModel.error)
        .kbSuccessAlert(isPresented: $viewModel.success, title: "Value updated")
        .onReceive(NotificationCenter.default.publisher(for: .userDefaultsInspectorDidChange)) { notification in
            guard let changedKey = notification.userInfo?[UserDefaultsInspectorNotificationKeys.key] as? String else {
                return
            }
            if changedKey == viewModel.key {
                let action = notification.userInfo?[UserDefaultsInspectorNotificationKeys.action] as? String
                if action == UserDefaultsInspectorChangeAction.deleted.rawValue {
                    dismiss()
                } else {
                    viewModel.reload()
                }
            }
        }

        .sheet(isPresented: $isPresentingEditValue) {
            NavigationStack {
                UserDefaultsValueEditView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section(header: Text("Info")) {
            fieldView(title: "Key", value: viewModel.key)
            fieldView(title: "Type", value: viewModel.typeName)
            if let knownKey = viewModel.knownKey {
                fieldView(title: "Category", value: knownKey.category.title)
                fieldView(title: "Expected Type", value: knownKey.valueType.rawValue)
                VStack(alignment: .leading) {
                    Text("Description")
                        .foregroundColor(Color.secondary)
                    Text(knownKey.description)
                        .foregroundColor(Color.primary)
                }
                .padding(.vertical, 5)
            }
            if let archived = viewModel.archivedFieldsNote {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Archived fields")
                        .foregroundColor(Color.secondary)
                    Text(archived)
                        .foregroundColor(Color.primary)
                        .font(.caption2)
                }
                .padding(.vertical, 5)
            }
        }
    }

    // MARK: - Value Section

    private var valueSection: some View {
        Section(header: Text("Value")) {
            if viewModel.valueType == .bool {
                boolEditorView()
            } else {
                nonBooleanValueView()
            }
        }
    }

    private func boolEditorView() -> some View {
        Toggle("Value", isOn: Binding(
            get: { viewModel.boolValue },
            set: {
                viewModel.boolValue = $0
                viewModel.didUpdateActionRequested()
            }
        ))
    }

    private func nonBooleanValueView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SelectableValueTextView(
                text: viewModel.valuePreviewText,
                isMonospaced: viewModel.valueType == .json || (viewModel.valueType == .data && viewModel.decodedDataAsJSON),
                measuredHeight: $valueTextHeight
            )
            .frame(height: max(25, valueTextHeight))

            if viewModel.canEditValue {
                Button("Edit value") {
                    isPresentingEditValue = true
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.accentColor)
            } else if viewModel.valueType == .data {
                Text("Data values are read-only")
                    .font(.caption2)
                    .foregroundColor(Color.secondary)
            }
        }
    }

    private var optionsMenu: some View {
        Menu {
            copyButton(value: viewModel.key, title: "Copy Key")

            Button(role: .destructive, action: {
                viewModel.didDeleteActionRequested()
            }, label: {
                Label("Delete Key", systemImage: "trash")
            })
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Helpers

    private func fieldView(title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundColor(Color.secondary)
            Text(value)
                .foregroundColor(Color.primary)
        }
        .padding(.vertical, 5)
    }

    private func copyButton(value: String, title: String = "Copy") -> some View {
        Button(action: {
            UIPasteboard.general.string = value
        }, label: {
            Text(title)
            Image(systemName: "doc.on.doc")
        })
    }
}

private struct SelectableValueTextView: UIViewRepresentable {
    let text: String
    let isMonospaced: Bool
    @Binding var measuredHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.adjustsFontForContentSizeCategory = true
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.font = isMonospaced
            ? UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .regular)
            : UIFont.preferredFont(forTextStyle: .body)
        uiView.textColor = UIColor(Color.primary)
        uiView.text = text

        DispatchQueue.main.async {
            let fittingSize = uiView.sizeThatFits(
                CGSize(width: uiView.bounds.width, height: .greatestFiniteMagnitude)
            )
            let nextHeight = ceil(fittingSize.height)
            if nextHeight > 0, abs(measuredHeight - nextHeight) > 0.5 {
                measuredHeight = nextHeight
            }
        }
    }
}
