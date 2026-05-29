//
//  UserDefaultsListView.swift
//  KnowledgeBaseApp
//
//  Created by danil.korotaev on 15.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import SwiftUI



struct UserDefaultsListView: View {
    @StateObject
    private var viewModel = ViewModel()

    @State private var isPresentingAdd = false
    @State private var isPresentingSettings = false

    var body: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section(header: sectionHeader(for: section)) {
                    ForEach(section.items) { item in
                        row(for: item)
                    }
                    .onDelete { offsets in
                        viewModel.deleteItems(in: section, at: offsets)
                    }
                }
            }
        }
        .onAppear {
            viewModel.didLoadView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDefaultsInspectorDidChange)) { _ in
            viewModel.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDefaultsServiceDidHandleOperation)) { notification in
            guard
                let event = notification.userInfo?["event"] as? UserDefaultsServiceEvent,
                event.isWrite
            else {
                return
            }
            viewModel.reload()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                settingsButton
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                addButton
            }
            ToolbarItem(placement: .bottomBar) {
                filterPicker
            }
            ToolbarItem(placement: .bottomBar) {
                sortPicker
            }
            ToolbarItem(placement: .bottomBar) {
                systemKeysToggle
            }
        }
        .navigationTitle("UserDefaults")
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()

        .sheet(isPresented: $isPresentingAdd) {
            NavigationStack {
                UserDefaultsAddView()
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            NavigationStack {
                UserDefaultsInspectorSettingsView()
            }
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(for section: SectionItem) -> some View {
        if let title = section.title {
            Text(title)
        } else {
            EmptyView()
        }
    }

    // MARK: - Toolbar

    private var addButton: some View {
        Button {
            isPresentingAdd = true
        } label: {
            Image(systemName: "plus")
        }
        .foregroundColor(Color.accentColor)
    }

    private var settingsButton: some View {
        Button {
            isPresentingSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .foregroundColor(Color.accentColor)
    }

    private var filterPicker: some View {
        Picker("", selection: $viewModel.filterType) {
            ForEach(FilterType.allCases, id: \.self) {
                Text($0.name)
            }
        }
    }

    private var sortPicker: some View {
        Picker("", selection: $viewModel.sortType) {
            ForEach(SortType.allCases, id: \.self) {
                Text($0.name)
            }
        }
    }

    private var systemKeysToggle: some View {
        Button {
            viewModel.showSystemKeys.toggle()
        } label: {
            Image(systemName: viewModel.showSystemKeys ? "eye.fill" : "eye.slash")
        }
        .foregroundColor(Color.accentColor)
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for item: Item) -> some View {
        NavigationLink(destination: UserDefaultsDetailView(key: item.key)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.key)
                        .font(.callout)
                        .lineLimit(2)
                    Spacer()
                    Text(item.typeName)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                }
                Text(item.valuePreview)
                    .font(.caption)
                    .foregroundColor(Color.secondary)
                    .lineLimit(1)
                if let knownKey = item.knownKey {
                    HStack(spacing: 4) {
                        Text(knownKey.category.title)
                            .font(.caption2)
                            .foregroundColor(Color.accentColor)
                        Text("·")
                            .font(.caption2)
                            .foregroundColor(Color.secondary)
                        Text(knownKey.description)
                            .font(.caption2)
                            .foregroundColor(Color.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
