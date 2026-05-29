//
//  UserDefaultsInspectorService.swift
//  KnowledgeBaseApp
//
//  Created by danil.korotaev on 17.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import Foundation


protocol UserDefaultsInspectorServiceDescription {
    var systemKeyPrefixes: [String] { get }

    func items() -> [UserDefaultsInspectorItem]
    func item(for key: String) -> UserDefaultsInspectorItem?
    func save(update: UserDefaultsInspectorUpdate, for key: String) throws -> UserDefaultsInspectorItem
    func delete(key: String)
    func reset()
    func isSystemKey(_ key: String) -> Bool
}

enum UserDefaultsInspectorServiceError: LocalizedError {
    case invalidNumber
    case invalidJSON
    case unsupportedType
    case dataNotEditable
    case valueMissingAfterSave

    var errorDescription: String? {
        switch self {
        case .invalidNumber: "Invalid number format"
        case .invalidJSON: "Invalid JSON format"
        case .unsupportedType: "This type cannot be created manually"
        case .dataNotEditable: "Data values cannot be edited as text"
        case .valueMissingAfterSave: "Value is missing after save"
        }
    }
}

final class UserDefaultsInspectorService: UserDefaultsInspectorServiceDescription {
    static let shared = UserDefaultsInspectorService()

    let systemKeyPrefixes = [
        "Apple",
        "NS",
        "com.apple",
        "AK",
        "PKPayment",
        "AddingEmojiKeybordHandled",
        "INNext",
        "WebKit"
    ]

    private let userDefaultsService: UserDefaultsServiceDescription
    private let notificationCenter: NotificationCenter

    init(
        userDefaultsService: UserDefaultsServiceDescription = UserDefaultsService.shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.userDefaultsService = userDefaultsService
        self.notificationCenter = notificationCenter
    }

    func items() -> [UserDefaultsInspectorItem] {
        userDefaultsService.dictionaryRepresentation().map { key, value in
            makeItem(key: key, rawValue: value)
        }
    }

    func item(for key: String) -> UserDefaultsInspectorItem? {
        makeItem(key: key, rawValue: userDefaultsService.object(forKey: key))
    }

    func save(update: UserDefaultsInspectorUpdate, for key: String) throws -> UserDefaultsInspectorItem {
        let action: UserDefaultsInspectorChangeAction = userDefaultsService.object(forKey: key) == nil ? .added : .updated
        let storedValue = try UserDefaultsDebugValueCodec.makeStoredValue(for: update)
        userDefaultsService.set(storedValue, forKey: key)

        guard let item = item(for: key) else {
            throw UserDefaultsInspectorServiceError.valueMissingAfterSave
        }

        postChange(action: action, key: key)
        return item
    }

    func delete(key: String) {
        userDefaultsService.removeObject(forKey: key)
        postChange(action: .deleted, key: key)
    }

    func reset() {
        userDefaultsService.dictionaryRepresentation().keys.forEach {
            userDefaultsService.removeObject(forKey: $0)
        }
        postChange(action: .reset, key: nil)
    }

    func isSystemKey(_ key: String) -> Bool {
        systemKeyPrefixes.contains { key.hasPrefix($0) }
    }

    private func makeItem(key: String, rawValue: Any?) -> UserDefaultsInspectorItem {
        UserDefaultsInspectorItem(
            key: key,
            knownKey: UserDefaultsKeyRegistry.knownKey(for: key),
            rawValue: rawValue,
            snapshot: UserDefaultsDebugValueCodec.makeSnapshot(from: rawValue)
        )
    }

    private func postChange(action: UserDefaultsInspectorChangeAction, key: String?) {
        var userInfo: [String: Any] = [
            UserDefaultsInspectorNotificationKeys.action: action.rawValue
        ]
        if let key {
            userInfo[UserDefaultsInspectorNotificationKeys.key] = key
        }

        notificationCenter.post(
            name: .userDefaultsInspectorDidChange,
            object: self,
            userInfo: userInfo
        )
    }
}
