//
//  UserDefaultsDebugModels.swift
//  KnowledgeBaseApp
//
//  Created by danil.korotaev on 17.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import Foundation

enum UserDefaultsInspectorChangeAction: String {
    case added
    case updated
    case deleted
    case reset
}

enum UserDefaultsInspectorArchivedValueStrategy {
    case keyedArchive
    case plist

    var displayName: String {
        switch self {
        case .keyedArchive:
            return "NSKeyedArchiver"
        case .plist:
            return "PropertyList"
        }
    }
}

struct UserDefaultsInspectorValueSnapshot {
    let typeName: String
    let valueType: UserDefaultsValueType
    let stringValue: String
    let boolValue: Bool
    let dateValue: Date
    let dataSize: String
    let decodedDataAsJSON: Bool
    let archivedValuePaths: [String: UserDefaultsInspectorArchivedValueStrategy]

    var archivedFieldsDetailed: [String] {
        archivedValuePaths
            .map { path, strategy in
                "\(path) (\(strategy.displayName))"
            }
            .sorted()
    }

    var archivedFieldsNote: String? {
        let values = archivedFieldsDetailed
        guard values.isEmpty == false else {
            return nil
        }
        return values.joined(separator: "\n")
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
}

struct UserDefaultsInspectorItem: Identifiable {
    let key: String
    let knownKey: KnownUserDefaultsKey?
    let rawValue: Any?
    let snapshot: UserDefaultsInspectorValueSnapshot

    var id: String { key }
    var isKnown: Bool { knownKey != nil }

    var searchableText: String {
        [
            key,
            knownKey?.description ?? "",
            knownKey?.category.title ?? "",
            snapshot.valuePreviewText
        ]
            .joined(separator: "\n")
            .lowercased()
    }
}

struct UserDefaultsInspectorUpdate {
    let valueType: UserDefaultsValueType
    let stringValue: String
    let boolValue: Bool
    let dateValue: Date
    let decodedDataAsJSON: Bool
    let archivedValuePaths: [String: UserDefaultsInspectorArchivedValueStrategy]
}

extension Notification.Name {
    static let userDefaultsInspectorDidChange = Notification.Name("com.coredan.CoreDanVPN.userDefaultsInspectorDidChange")
}

enum UserDefaultsInspectorNotificationKeys {
    static let action = "action"
    static let key = "key"
}
