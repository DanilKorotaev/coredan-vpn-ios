//
//  UserDefaultsDebugValueCodec.swift
//  KnowledgeBaseApp
//
//  Created by danil.korotaev on 17.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import Foundation

enum UserDefaultsDebugValueCodec {
    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    static func makeSnapshot(from rawValue: Any?) -> UserDefaultsInspectorValueSnapshot {
        let valueType = detectType(rawValue)
        let typeName = rawValue.map { String(describing: type(of: $0)) } ?? "nil"

        switch valueType {
        case .bool:
            let boolValue = rawValue as? Bool ?? false
            return .init(
                typeName: typeName,
                valueType: valueType,
                stringValue: "\(boolValue)",
                boolValue: boolValue,
                dateValue: Date(),
                dataSize: "",
                decodedDataAsJSON: false,
                archivedValuePaths: [:]
            )
        case .integer, .double:
            return .init(
                typeName: typeName,
                valueType: valueType,
                stringValue: rawValue.map { "\($0)" } ?? "",
                boolValue: false,
                dateValue: Date(),
                dataSize: "",
                decodedDataAsJSON: false,
                archivedValuePaths: [:]
            )
        case .string:
            return .init(
                typeName: typeName,
                valueType: valueType,
                stringValue: rawValue as? String ?? "",
                boolValue: false,
                dateValue: Date(),
                dataSize: "",
                decodedDataAsJSON: false,
                archivedValuePaths: [:]
            )
        case .date:
            return .init(
                typeName: typeName,
                valueType: valueType,
                stringValue: "",
                boolValue: false,
                dateValue: rawValue as? Date ?? Date(),
                dataSize: "",
                decodedDataAsJSON: false,
                archivedValuePaths: [:]
            )
        case .data:
            if let data = rawValue as? Data,
               let jsonObject = try? JSONSerialization.jsonObject(with: data),
               JSONSerialization.isValidJSONObject(jsonObject) {
                let normalized = prettyJSONWithMetadata(jsonObject)
                return .init(
                    typeName: typeName,
                    valueType: valueType,
                    stringValue: normalized.pretty,
                    boolValue: false,
                    dateValue: Date(),
                    dataSize: "",
                    decodedDataAsJSON: true,
                    archivedValuePaths: normalized.archivedValuePaths
                )
            }
            let size = (rawValue as? Data).map { "\($0.count) bytes" } ?? "nil"
            return .init(
                typeName: typeName,
                valueType: valueType,
                stringValue: "",
                boolValue: false,
                dateValue: Date(),
                dataSize: size,
                decodedDataAsJSON: false,
                archivedValuePaths: [:]
            )
        case .json:
            let normalized = prettyJSONWithMetadata(rawValue as Any)
            return .init(
                typeName: typeName,
                valueType: valueType,
                stringValue: normalized.pretty,
                boolValue: false,
                dateValue: Date(),
                dataSize: "",
                decodedDataAsJSON: false,
                archivedValuePaths: normalized.archivedValuePaths
            )
        case .unknown:
            return .init(
                typeName: typeName,
                valueType: valueType,
                stringValue: rawValue.map { String(describing: $0) } ?? "",
                boolValue: false,
                dateValue: Date(),
                dataSize: "",
                decodedDataAsJSON: false,
                archivedValuePaths: [:]
            )
        }
    }

    static func makeStoredValue(for update: UserDefaultsInspectorUpdate) throws -> Any {
        switch update.valueType {
        case .bool:
            return update.boolValue
        case .integer:
            guard let intVal = Int(update.stringValue) else {
                throw UserDefaultsInspectorServiceError.invalidNumber
            }
            return intVal
        case .double:
            guard let doubleVal = Double(update.stringValue) else {
                throw UserDefaultsInspectorServiceError.invalidNumber
            }
            return doubleVal
        case .string:
            return update.stringValue
        case .date:
            return update.dateValue
        case .data:
            guard update.decodedDataAsJSON else {
                throw UserDefaultsInspectorServiceError.dataNotEditable
            }
            guard let data = update.stringValue.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: data)
            else {
                throw UserDefaultsInspectorServiceError.invalidJSON
            }
            let transformed = applyingArchivedValueStrategies(
                to: jsonObject,
                archivedValuePaths: update.archivedValuePaths
            )
            guard let serialized = try? JSONSerialization.data(withJSONObject: transformed) else {
                throw UserDefaultsInspectorServiceError.invalidJSON
            }
            return serialized
        case .json:
            guard let data = update.stringValue.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: data)
            else {
                throw UserDefaultsInspectorServiceError.invalidJSON
            }
            return applyingArchivedValueStrategies(
                to: jsonObject,
                archivedValuePaths: update.archivedValuePaths
            )
        case .unknown:
            return update.stringValue
        }
    }

    static func detectType(_ value: Any?) -> UserDefaultsValueType {
        guard let value else {
            return .unknown
        }
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
            return .bool
        }
        switch value {
        case is Int: return .integer
        case is Double, is Float: return .double
        case is String: return .string
        case is Date: return .date
        case is Data: return .data
        case is [Any], is [String: Any], is NSArray, is NSDictionary: return .json
        default: return .unknown
        }
    }

    // MARK: - Normalize / Archive

    private struct PrettyJSONResult {
        let pretty: String
        let archivedValuePaths: [String: UserDefaultsInspectorArchivedValueStrategy]
    }

    private static func prettyJSONWithMetadata(_ value: Any) -> PrettyJSONResult {
        var archivedValuePaths: [String: UserDefaultsInspectorArchivedValueStrategy] = [:]
        guard let normalizedValue = normalizedJSONValue(from: value, path: "", archivedValuePaths: &archivedValuePaths),
              JSONSerialization.isValidJSONObject(normalizedValue),
              let data = try? JSONSerialization.data(withJSONObject: normalizedValue, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8)
        else {
            return PrettyJSONResult(pretty: String(describing: value), archivedValuePaths: [:])
        }
        return PrettyJSONResult(pretty: string, archivedValuePaths: archivedValuePaths)
    }

    private static func normalizedJSONValue(
        from value: Any,
        path: String,
        archivedValuePaths: inout [String: UserDefaultsInspectorArchivedValueStrategy]
    ) -> Any? {
        switch value {
        case let dictionary as [String: Any]:
            var result: [String: Any] = [:]
            for (key, item) in dictionary {
                let nextPath = path.isEmpty ? key : "\(path).\(key)"
                result[key] = normalizedJSONValue(from: item, path: nextPath, archivedValuePaths: &archivedValuePaths) ?? NSNull()
            }
            return result
        case let dictionary as NSDictionary:
            var result: [String: Any] = [:]
            for case let key as NSString in dictionary.allKeys {
                let raw = dictionary[key] ?? NSNull()
                let keyString = key as String
                let nextPath = path.isEmpty ? keyString : "\(path).\(keyString)"
                result[keyString] = normalizedJSONValue(from: raw, path: nextPath, archivedValuePaths: &archivedValuePaths) ?? NSNull()
            }
            return result
        case let array as [Any]:
            return array.enumerated().map { index, item in
                let nextPath = "\(path)[\(index)]"
                return normalizedJSONValue(from: item, path: nextPath, archivedValuePaths: &archivedValuePaths) ?? NSNull()
            }
        case let array as NSArray:
            return array.enumerated().map { index, item in
                let nextPath = "\(path)[\(index)]"
                return normalizedJSONValue(from: item, path: nextPath, archivedValuePaths: &archivedValuePaths) ?? NSNull()
            }
        case let data as Data:
            return normalizedJSONDataValue(from: data, path: path, archivedValuePaths: &archivedValuePaths)
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID():
            return number.boolValue
        case let number as NSNumber:
            return number
        case let string as NSString:
            return string as String
        case is NSNull:
            return NSNull()
        default:
            return String(describing: value)
        }
    }

    private static func normalizedJSONDataValue(
        from data: Data,
        path: String,
        archivedValuePaths: inout [String: UserDefaultsInspectorArchivedValueStrategy]
    ) -> Any {
        if let archivedObject = decodedArchivedObject(from: data),
           !(archivedObject is NSData) {
            archivedValuePaths[path] = .keyedArchive
            return normalizedJSONValue(from: archivedObject, path: path, archivedValuePaths: &archivedValuePaths) ?? NSNull()
        }

        var format = PropertyListSerialization.PropertyListFormat.binary
        if let plistObject = try? PropertyListSerialization.propertyList(from: data, options: [], format: &format) {
            archivedValuePaths[path] = .plist
            return normalizedJSONValue(from: plistObject, path: path, archivedValuePaths: &archivedValuePaths) ?? NSNull()
        }

        if let jsonObject = try? JSONSerialization.jsonObject(with: data) {
            return normalizedJSONValue(from: jsonObject, path: path, archivedValuePaths: &archivedValuePaths) ?? NSNull()
        }

        if let utf8String = String(data: data, encoding: .utf8), utf8String.isEmpty == false {
            return utf8String
        }

        return ["__type": "Data", "base64": data.base64EncodedString()]
    }

    private static func applyingArchivedValueStrategies(
        to jsonObject: Any,
        archivedValuePaths: [String: UserDefaultsInspectorArchivedValueStrategy]
    ) -> Any {
        guard archivedValuePaths.isEmpty == false else {
            return jsonObject
        }

        guard var root = jsonObject as? [String: Any] else {
            return jsonObject
        }

        for (path, strategy) in archivedValuePaths {
            guard let valueAtPath = value(in: root, path: path) else { continue }
            guard let encoded = encodedValue(for: valueAtPath, strategy: strategy) else { continue }
            setValue(encoded, in: &root, path: path)
        }

        return root
    }

    private static func encodedValue(for value: Any, strategy: UserDefaultsInspectorArchivedValueStrategy) -> Any? {
        switch strategy {
        case .keyedArchive:
            return try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false)
        case .plist:
            return try? PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
        }
    }

    private static func value(in root: [String: Any], path: String) -> Any? {
        let parts = pathParts(path)
        var current: Any = root

        for part in parts {
            switch part {
            case .key(let key):
                if let dict = current as? [String: Any], let next = dict[key] {
                    current = next
                } else {
                    return nil
                }
            case .index(let index):
                if let array = current as? [Any], array.indices.contains(index) {
                    current = array[index]
                } else {
                    return nil
                }
            }
        }
        return current
    }

    private static func setValue(_ newValue: Any, in root: inout [String: Any], path: String) {
        let parts = pathParts(path)
        guard parts.isEmpty == false else {
            return
        }

        func set(_ container: inout Any, _ pathParts: ArraySlice<PathPart>) {
            guard let head = pathParts.first else {
                return
            }
            let tail = pathParts.dropFirst()

            switch head {
            case .key(let key):
                var dict = (container as? [String: Any]) ?? [:]
                if tail.isEmpty {
                    dict[key] = newValue
                    container = dict
                    return
                }
                var next: Any = dict[key] ?? [:]
                set(&next, tail)
                dict[key] = next
                container = dict
            case .index(let index):
                var array = (container as? [Any]) ?? []
                if array.indices.contains(index) == false {
                    array.append(contentsOf: Array(repeating: NSNull(), count: max(0, index - array.count + 1)))
                }
                if tail.isEmpty {
                    array[index] = newValue
                    container = array
                    return
                }
                var next: Any = array[index]
                set(&next, tail)
                array[index] = next
                container = array
            }
        }

        var container: Any = root
        set(&container, parts[...])
        root = (container as? [String: Any]) ?? root
    }

    private enum PathPart {
        case key(String)
        case index(Int)
    }

    private static func pathParts(_ path: String) -> [PathPart] {
        var result: [PathPart] = []
        var buffer = ""
        var i = path.startIndex

        func flushKeyIfNeeded() {
            if buffer.isEmpty == false {
                result.append(.key(buffer))
                buffer = ""
            }
        }

        while i < path.endIndex {
            let character = path[i]
            if character == "." {
                flushKeyIfNeeded()
                i = path.index(after: i)
                continue
            }
            if character == "[" {
                flushKeyIfNeeded()
                let close = path[i...].firstIndex(of: "]") ?? path.endIndex
                let numberStart = path.index(after: i)
                let numberString = String(path[numberStart..<close])
                if let index = Int(numberString) {
                    result.append(.index(index))
                }
                i = close < path.endIndex ? path.index(after: close) : close
                continue
            }
            buffer.append(character)
            i = path.index(after: i)
        }
        flushKeyIfNeeded()
        return result
    }

    private static func decodedArchivedObject(from data: Data) -> Any? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else {
            return nil
        }
        unarchiver.requiresSecureCoding = false
        let object = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
        unarchiver.finishDecoding()
        return object
    }
}
