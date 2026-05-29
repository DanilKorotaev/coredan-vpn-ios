//
//  UserDefaultsDetailView+ViewModel.swift
//  KnowledgeBaseApp
//
//  Created by danil.korotaev on 15.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import Foundation
import SwiftUI

extension UserDefaultsDetailView {
    final class ViewModel: ObservableObject {
        let key: String

        @Published private(set) var knownKey: KnownUserDefaultsKey?
        @Published var valueType: UserDefaultsValueType
        @Published var stringValue: String = ""
        @Published var boolValue: Bool = false
        @Published var dateValue: Date = Date()
        @Published var dataSize: String = ""
        @Published var success: Bool = false
        @Published var error: Error?

        private let service: UserDefaultsInspectorServiceDescription
        private var runtimeTypeName: String
        private(set) var decodedDataAsJSON: Bool = false
        private var archivedValuePaths: [String: UserDefaultsInspectorArchivedValueStrategy] = [:]

        init(key: String, service: UserDefaultsInspectorServiceDescription = UserDefaultsInspectorService.shared) {
            self.key = key
            self.service = service
            self.valueType = .unknown
            self.runtimeTypeName = "nil"
            loadItem()
        }

        var typeName: String {
            runtimeTypeName
        }

        var archivedFields: [String] {
            archivedValuePaths.keys.sorted()
        }

        var archivedFieldsDetailed: [String] {
            archivedValuePaths
                .map { path, strategy in
                    "\(path) (\(strategy.displayName))"
                }
                .sorted()
        }

        var archivedFieldsNote: String? {
            let details = archivedFieldsDetailed
            guard details.isEmpty == false else {
                return nil
            }
            return details.joined(separator: "\n")
        }

        var canEditValue: Bool {
            switch valueType {
            case .bool:
                return false
            case .data:
                return decodedDataAsJSON
            default:
                return true
            }
        }

        var valuePreviewText: String {
            switch valueType {
            case .bool:
                return "\(boolValue)"
            case .date:
                return UserDefaultsDebugValueCodec.displayDateFormatter.string(from: dateValue)
            case .data:
                return decodedDataAsJSON ? stringValue : dataSize
            default:
                return stringValue
            }
        }

        func didUpdateActionRequested() {
            do {
                let update = UserDefaultsInspectorUpdate(
                    valueType: valueType,
                    stringValue: stringValue,
                    boolValue: boolValue,
                    dateValue: dateValue,
                    decodedDataAsJSON: decodedDataAsJSON,
                    archivedValuePaths: archivedValuePaths
                )
                let item = try service.save(update: update, for: key)
                apply(item: item)
                success = true
            } catch {
                self.error = error
            }
        }

        func didDeleteActionRequested() {
            service.delete(key: key)
        }

        func reload() {
            loadItem()
        }

        private func loadItem() {
            guard let item = service.item(for: key) else {
                runtimeTypeName = "nil"
                valueType = .unknown
                stringValue = ""
                boolValue = false
                dateValue = Date()
                dataSize = ""
                decodedDataAsJSON = false
                archivedValuePaths = [:]
                return
            }
            apply(item: item)
        }

        private func apply(item: UserDefaultsInspectorItem) {
            let snapshot = item.snapshot
            knownKey = item.knownKey
            valueType = snapshot.valueType
            runtimeTypeName = snapshot.typeName
            stringValue = snapshot.stringValue
            boolValue = snapshot.boolValue
            dateValue = snapshot.dateValue
            dataSize = snapshot.dataSize
            decodedDataAsJSON = snapshot.decodedDataAsJSON
            archivedValuePaths = snapshot.archivedValuePaths
            if valueType != .data {
                dataSize = ""
            }
        }
    }
}
