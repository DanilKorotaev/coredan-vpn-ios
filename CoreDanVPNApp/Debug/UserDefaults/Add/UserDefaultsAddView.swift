//
//  UserDefaultsAddView.swift
//  KnowledgeBaseApp
//
//  Created by danil.korotaev on 15.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import SwiftUI


struct UserDefaultsAddView: View {
    @SwiftUI.Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ViewModel

    init() {
        _viewModel = StateObject(wrappedValue: ViewModel())
    }

    var body: some View {
        Form {
            keyInputSection
            valueTypeSection
            valueInputSection
            saveSection
        }
        .navigationTitle("Add Key")
        .navigationBarTitleDisplayMode(.inline)
        .kbErrorAlert(error: $viewModel.error)
        .kbSuccessAlert(isPresented: $viewModel.success, title: "Value saved")
        .onChange(of: viewModel.success) { _, success in
            if success {
                dismiss()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDefaultsInspectorDidChange)) { notification in
            let changedKey = notification.userInfo?[UserDefaultsInspectorNotificationKeys.key] as? String
            viewModel.handleExternalChange(changedKey: changedKey)
        }
    }

    // MARK: - Key Input

    private var keyInputSection: some View {
        Section(header: Text("Key")) {
            Picker("Input Mode", selection: $viewModel.keyInputMode) {
                ForEach(KeyInputMode.allCases) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)

            switch viewModel.keyInputMode {
            case .registry:
                NavigationLink(
                    destination: UserDefaultsRegistryKeySelectionView(
                        selectedKey: $viewModel.selectedRegistryKey,
                        groupedKeys: viewModel.groupedKeys
                    )
                ) {
                    HStack {
                        Text("Key")
                        Spacer()
                        Text(viewModel.selectedRegistryKey?.key.rawValue ?? "Select a key...")
                            .foregroundColor(
                                viewModel.selectedRegistryKey == nil
                                ? Color.secondary
                                : Color.primary
                            )
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            case .manual:
                TextField("Enter key", text: $viewModel.manualKey)
                    .autocapitalization(.none)
                    .keyboardType(.asciiCapable)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            if let selected = viewModel.selectedRegistryKey, viewModel.keyInputMode == .registry {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selected.key.rawValue)
                        .font(.caption)
                        .foregroundColor(Color.primary)
                    Text(selected.description)
                        .font(.caption2)
                        .foregroundColor(Color.secondary)
                }
            }
        }
    }

    // MARK: - Value Type

    private var valueTypeSection: some View {
        Section(header: Text("Type")) {
            Picker("Value Type", selection: $viewModel.valueType) {
                ForEach(UserDefaultsValueType.addableCases) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Value Input

    @ViewBuilder
    private var valueInputSection: some View {
        Section(header: Text("Value")) {
            switch viewModel.valueType {
            case .bool:
                Toggle("Value", isOn: $viewModel.boolValue)
            case .string:
                TextField("Enter value", text: $viewModel.stringValue)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            case .integer, .double:
                TextField("Enter number", text: $viewModel.stringValue)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            case .date:
                DatePicker("Value", selection: $viewModel.dateValue)
            case .json:
                TextEditor(text: $viewModel.stringValue)
                    .frame(minHeight: 80)
                    .cornerRadius(8.0)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    .autocapitalization(.none)
            case .data, .unknown:
                Text("This type cannot be created manually")
                    .foregroundColor(Color.secondary)
            }
        }
    }

    // MARK: - Save

    private var saveSection: some View {
        Section {
            Button(action: viewModel.didSaveActionRequested) {
                Text("Save")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.canSave)
        }
    }
}
