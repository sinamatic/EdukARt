import Foundation
import CoreFoundation

extension RobotROSSettings {
    enum Block: String {
        case operatingMode
        case lights

        var enabledKey: String { "robotROS." + rawValue + ".enabled" }

        var isEnabled: Bool {
            RobotROSSettings.activeStore?.object(forKey: enabledKey) as? Bool ?? true
        }

        var textFields: [TextField] {
            switch self {
            case .operatingMode: return [.modeService, .modeServiceType]
            case .lights: return [.allLights, .leftLights, .rightLights]
            }
        }

        var numberFields: [NumberField] {
            switch self {
            case .operatingMode:
                return [.enabledMode, .disabledMode, .mecanum, .offroad,
                        .featureMode, .enabledDisableFeature, .disabledDisableFeature]
            case .lights:
                return [.lightOff, .lightDim, .lightFlash, .lightPulsation, .lightRotation, .lightRunning]
            }
        }

        func text(in store: UserDefaults) -> String {
            var values: [String: Any] = ["enabled": store.object(forKey: enabledKey) as? Bool ?? true]
            for field in textFields {
                values[field.rawValue] = store.string(forKey: field.key) ?? field.defaultValue
            }
            for field in numberFields {
                values[field.rawValue] = store.object(forKey: field.key) as? Int ?? field.defaultValue
            }
            guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]),
                  let text = String(data: data, encoding: .utf8) else { return "{}" }
            return text
        }

        /// Validate the entire block before updating any persisted values.
        func save(_ text: String, in store: UserDefaults) throws {
            guard let data = text.data(using: .utf8),
                  let values = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ConfigurationError("Enter a JSON object.")
            }
            let allowedKeys = Set(["enabled"] + textFields.map(\.rawValue) + numberFields.map(\.rawValue))
            guard Set(values.keys).isSubset(of: allowedKeys) else {
                throw ConfigurationError("Unknown setting. Keep the existing field names.")
            }
            let enabled: Bool
            if values.isEmpty {
                enabled = false
            } else if let number = values["enabled"] as? NSNumber,
                      CFGetTypeID(number) == CFBooleanGetTypeID() {
                enabled = number.boolValue
            } else {
                throw ConfigurationError("Set enabled to true or false. An empty object disables this feature.")
            }
            for field in textFields where values[field.rawValue] != nil {
                guard let value = values[field.rawValue] as? String,
                      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ConfigurationError("\(field.rawValue) must be a nonempty string.")
                }
            }
            for field in numberFields where values[field.rawValue] != nil {
                guard let value = values[field.rawValue] as? NSNumber,
                      CFGetTypeID(value) != CFBooleanGetTypeID(),
                      Int(value.stringValue) != nil else {
                    throw ConfigurationError("\(field.rawValue) must be an integer.")
                }
            }
            // Only validated keys reach storage. Missing keys keep their previous values.
            for (key, value) in values where key != "enabled" {
                store.set(value, forKey: "robotROS." + key)
            }
            store.set(enabled, forKey: enabledKey)
        }
    }

    struct ConfigurationError: LocalizedError {
        let message: String

        init(_ message: String) {
            self.message = message
        }

        var errorDescription: String? { message }
    }

    static func resetKeepingNamespace(in store: UserDefaults) {
        for field in TextField.allCases where field != .namespace {
            store.removeObject(forKey: field.key)
        }
        for field in NumberField.allCases {
            store.removeObject(forKey: field.key)
        }
        store.removeObject(forKey: Block.operatingMode.enabledKey)
        store.removeObject(forKey: Block.lights.enabledKey)
    }
}
