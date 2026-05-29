//
//  UserDefaultsAddView+ViewModel.swift
//  KnowledgeBaseApp
//
//  Created by danil.korotaev on 15.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import Foundation
import SwiftUI

extension UserDefaultsAddView {
    enum KeyInputMode: String, CaseIterable, Identifiable {
        case registry = "From Registry"
        case manual = "Manual"

        var id: String { rawValue }
    }

    final class ViewModel: ObservableObject {
        @Published var keyInputMode: KeyInputMode = .registry
        @Published var manualKey: String = ""
        @Published var selectedRegistryKey: KnownUserDefaultsKey? {
            didSet {
                if let selected = selectedRegistryKey {
                    valueType = selected.valueType
                }
            }
        }
        @Published var valueType: UserDefaultsValueType = .string
        @Published var stringValue: String = ""
        @Published var boolValue: Bool = false
        @Published var dateValue: Date = Date()
        @Published var success: Bool = false
        @Published var error: Error?

        private let service: UserDefaultsInspectorServiceDescription
        let groupedKeys: [(category: UserDefaultsKeyCategory, keys: [KnownUserDefaultsKey])]

        var effectiveKey: String {
            switch keyInputMode {
            case .registry: selectedRegistryKey?.key.rawValue ?? ""
            case .manual: manualKey
            }
        }

        var canSave: Bool {
            !effectiveKey.isEmpty
        }

        init(service: UserDefaultsInspectorServiceDescription = UserDefaultsInspectorService.shared) {
            self.service = service

            let grouped = Dictionary(grouping: UserDefaultsKeyRegistry.allKeys, by: \.category)
            self.groupedKeys = grouped.keys.sorted { $0.title < $1.title }.map { category in
                (category: category, keys: grouped[category] ?? [])
            }
        }

        func didSaveActionRequested() {
            guard canSave else {
                return
            }

            do {
                try saveValue()
                success = true
            } catch {
                self.error = error
            }
        }

        func handleExternalChange(changedKey: String?) {
            guard let changedKey,
                  changedKey == effectiveKey,
                  let item = service.item(for: changedKey)
            else {
                return
            }
            valueType = item.snapshot.valueType
        }

        private func saveValue() throws {
            let key = effectiveKey
            let update = UserDefaultsInspectorUpdate(
                valueType: valueType,
                stringValue: stringValue,
                boolValue: boolValue,
                dateValue: dateValue,
                decodedDataAsJSON: false,
                archivedValuePaths: [:]
            )
            _ = try service.save(update: update, for: key)
        }
    }
}
