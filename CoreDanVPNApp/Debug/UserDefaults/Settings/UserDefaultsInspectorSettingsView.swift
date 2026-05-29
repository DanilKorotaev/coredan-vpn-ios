//
//  UserDefaultsInspectorSettingsView.swift
//  KnowledgeBaseApp
//
//  Created by danil.korotaev on 18.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import SwiftUI


struct UserDefaultsInspectorSettingsView: View {
    @StateObject
    private var viewModel = ViewModel()

    var body: some View {
        List {
            Section(
                header: Text("Logging"),
                footer: Text("Changes in verbose logging mode apply after app restart.")
            ) {
                Toggle("Enabled", isOn: $viewModel.isLoggingEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))

                Toggle("Verbose logs", isOn: $viewModel.isVerboseLoggingEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
            }

            Section(header: Text("Ignore add/update keys")) {
                HStack(spacing: 8) {
                    TextField("Enter full key", text: $viewModel.draftIgnoredKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Add") {
                        viewModel.addDraftIgnoredKey()
                    }
                    .disabled(viewModel.canAddDraftIgnoredKey == false)
                }

                ForEach(viewModel.ignoredKeys, id: \.self) { key in
                    Text(key)
                        .lineLimit(2)
                }
                .onDelete(perform: viewModel.deleteIgnoredKeys)
            }
        }
        .navigationTitle("UserDefaults Settings")
    }
}
