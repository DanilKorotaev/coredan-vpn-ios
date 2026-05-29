//
//  UserDefaultsRegistryKeySelectionView.swift
//  KnowledgeBaseApp
//
//  Created by Korotaev Danil on 17.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import SwiftUI


struct UserDefaultsRegistryKeySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedKey: KnownUserDefaultsKey?
    let groupedKeys: [(category: UserDefaultsKeyCategory, keys: [KnownUserDefaultsKey])]

    @State private var searchText = ""

    private var filteredGroups: [(category: UserDefaultsKeyCategory, keys: [KnownUserDefaultsKey])] {
        guard searchText.isEmpty == false else {
            return groupedKeys
        }

        let query = searchText.lowercased()
        return groupedKeys.compactMap { group in
            let keys = group.keys.filter { item in
                item.key.rawValue.lowercased().contains(query)
                || item.description.lowercased().contains(query)
                || item.category.title.lowercased().contains(query)
            }
            guard keys.isEmpty == false else {
                return nil
            }
            return (group.category, keys)
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    selectedKey = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("Select a key...")
                            .foregroundColor(Color.primary)
                        Spacer()
                        if selectedKey == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color.accentColor)
                        }
                    }
                }
            }

            ForEach(filteredGroups, id: \.category) { group in
                Section(header: Text(group.category.title)) {
                    ForEach(group.keys) { item in
                        Button {
                            selectedKey = item
                            dismiss()
                        } label: {
                            HStack(alignment: .center, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.key.rawValue)
                                        .foregroundColor(Color.primary)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                    Text(item.description)
                                        .foregroundColor(Color.secondary)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                if selectedKey?.id == item.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select key")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    }
}
