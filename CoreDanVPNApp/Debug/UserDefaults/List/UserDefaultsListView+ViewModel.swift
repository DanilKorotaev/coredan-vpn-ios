//
//  UserDefaultsListView+ViewModel.swift
//  KnowledgeBaseApp
//
//  Created by danil.korotaev on 15.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import Foundation
import SwiftUI

extension UserDefaultsListView {
    struct Item: Identifiable {
        let key: String
        let typeName: String
        let knownKey: KnownUserDefaultsKey?
        let valuePreview: String
        let searchIndex: String

        var id: String { key }
        var isKnown: Bool { knownKey != nil }
    }

    struct SectionItem: Identifiable {
        let title: String?
        let items: [Item]

        var id: String { title ?? "_flat" }
    }

    enum FilterType: String, CaseIterable {
        case all
        case known
        case unknown

        var name: String {
            switch self {
            case .all: "All"
            case .known: "Known"
            case .unknown: "Unknown"
            }
        }
    }

    enum SortType: String, CaseIterable {
        case key
        case category

        var name: String {
            switch self {
            case .key: "By Key"
            case .category: "By Category"
            }
        }
    }

    final class ViewModel: ObservableObject {
        @Published var sections: [SectionItem] = []
        @Published var searchText = "" { didSet { updateItems() } }
        @Published var filterType: FilterType = .all { didSet { updateItems() } }
        @Published var sortType: SortType = .category { didSet { updateItems() } }
        @Published var showSystemKeys = false { didSet { updateItems() } }

        private let service: UserDefaultsInspectorServiceDescription
        private var allItems: [Item] = []

        init(service: UserDefaultsInspectorServiceDescription = UserDefaultsInspectorService.shared) {
            self.service = service
        }

        func didLoadView() {
            reload()
        }

        func reload() {
            allItems = service.items().map { item in
                Item(
                    key: item.key,
                    typeName: item.snapshot.valueType.rawValue,
                    knownKey: item.knownKey,
                    valuePreview: item.snapshot.valuePreviewText.replacingOccurrences(of: "\n", with: ""),
                    searchIndex: item.searchableText
                )
            }
            updateItems()
        }

        func delete(key: String) {
            service.delete(key: key)
        }

        func deleteItems(in section: SectionItem, at offsets: IndexSet) {
            let keysToDelete = offsets.map { section.items[$0].key }
            keysToDelete.forEach { service.delete(key: $0) }
        }

        private func updateItems() {
            var items = allItems

            if !showSystemKeys {
                items = items.filter { item in
                    !service.isSystemKey(item.key)
                }
            }

            switch filterType {
            case .all:
                break
            case .known:
                items = items.filter(\.isKnown)
            case .unknown:
                items = items.filter { !$0.isKnown }
            }

            if !searchText.isEmpty {
                let query = searchText.lowercased()
                items = items.filter {
                    $0.searchIndex.contains(query)
                }
            }

            switch sortType {
            case .key:
                items.sort { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
                sections = [SectionItem(title: nil, items: items)]
            case .category:
                let grouped = Dictionary(grouping: items) { item -> String in
                    item.knownKey?.category.title ?? "Other"
                }
                sections = grouped.keys.sorted { lhs, rhs in
                    if lhs == "Other" {
                        return false
                    }
                    if rhs == "Other" {
                        return true
                    }
                    return lhs < rhs
                }.map { category in
                    let sectionItems = (grouped[category] ?? []).sorted {
                        $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
                    }
                    return SectionItem(title: category, items: sectionItems)
                }
            }
        }
    }
}
