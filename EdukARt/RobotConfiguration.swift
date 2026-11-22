import Foundation
import Combine
import Security

struct RobotConfiguration: Codable, Equatable {
    var host = "192.168.0.100"
    var udpPort = 50505
    var sshPort = 22
    var sshUsername = "user"
    var environment = "{}"
    var excludedAprilTagID: Int? = 0

    var namespace = "eduard/blue"
    var driveTopic = "cmd_vel"
    var driveType = "geometry_msgs/msg/Twist"
    var modeService = "set_mode"
    var modeServiceType = "edu_robot/srv/SetMode"
    var lightingTopic = "set_lighting_color"
    var lightingType = "edu_robot/msg/SetLightingColor"
    var allLights = "all"
    var leftLights = "left_side"
    var rightLights = "right_side"
    var enabledMode = 2
    var disabledMode = 0
    var mecanumMode = 2
    var offroadMode = 1
    var featureMode = 0
    var enabledDisableFeature = 0
    var disabledDisableFeature = 1
    var lightOff = 0
    var lightDim = 1
    var lightFlash = 2
    var lightPulsation = 3
    var lightRotation = 4
    var lightRunning = 5

    // Legacy flag retained only to decode configurations from the old settings view.
    var useCustomCommands = true
    var driveMessage = """
    {"kind":"publish","topic":"cmd_vel","messageType":"geometry_msgs/msg/Twist","message":{"linear":{"x":"$forward","y":"$sideways","z":0},"angular":{"x":0,"y":0,"z":"$rotation"}}}
    """
    var enableAction = """
    {"kind":"service","service":"set_mode","serviceType":"edu_robot/srv/SetMode","request":{"mode":{"mode":2,"drive_kinematic":"$driveKinematic","feature_mode":0},"disable_feature":0}}
    """
    var disableAction = """
    {"kind":"service","service":"set_mode","serviceType":"edu_robot/srv/SetMode","request":{"mode":{"mode":0,"drive_kinematic":"$driveKinematic","feature_mode":0},"disable_feature":1}}
    """
    var lightsAction = """
    {"kind":"publish","topic":"set_lighting_color","messageType":"edu_robot/msg/SetLightingColor","message":{"lighting_name":"$lightingName","r":"$red","g":"$green","b":"$blue","brightness":{"data":"$brightness"},"mode":"$mode"}}
    """
    var report = ""
    var lastDiscovery = ""

    static let defaults = RobotConfiguration()

    mutating func formatJSONFields() {
        driveMessage = Self.readableJSON(driveMessage)
        enableAction = Self.readableJSON(enableAction)
        disableAction = Self.readableJSON(disableAction)
        lightsAction = Self.readableJSON(lightsAction)
        environment = Self.readableJSON(environment)
    }

    private static func readableJSON(_ text: String) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)),
              let data = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
              ) else { return text }
        return String(decoding: data, as: UTF8.self)
    }

    func resolvedName(_ name: String) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("/") { return cleaned }
        let relative = cleaned.split(separator: "/").joined(separator: "/")
        let prefix = namespace.split(separator: "/").joined(separator: "/")
        if prefix.isEmpty || relative == prefix || relative.hasPrefix(prefix + "/") {
            return "/" + relative
        }
        return "/" + prefix + "/" + relative
    }

    func validate() throws {
        try validateConnection()
        let variables = try Self.object(environment)
        guard variables.allSatisfy({ key, value in
            key.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil && value is String
        }) else {
            throw RobotConfigurationError("ROS-Umgebung muss ein JSON-Objekt aus Textwerten sein.")
        }
        for (index, action) in [driveMessage, enableAction, disableAction, lightsAction].enumerated() {
            let object = try Self.object(action)
            if object.isEmpty && action != driveMessage { continue }
            let kind = object["kind"] as? String
            guard kind == (index == 0 || index == 3 ? "publish" : "service") else {
                throw RobotConfigurationError("JSON-Paket benötigt kind: publish oder service.")
            }
            let isService = kind == "service"
            guard let name = object[isService ? "service" : "topic"] as? String, !name.isEmpty,
                  let type = object[isService ? "serviceType" : "messageType"] as? String,
                  type.contains(isService ? "/srv/" : "/msg/"),
                  object[isService ? "request" : "message"] is [String: Any] else {
                throw RobotConfigurationError("Aktion benötigt Topic/Service, Typ und message/request als JSON-Objekt.")
            }
        }
    }

    func validateConnection() throws {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              udpPort > 0 && udpPort <= 65535,
              sshPort > 0 && sshPort <= 65535,
              !sshUsername.isEmpty else {
            throw RobotConfigurationError("Host, Benutzer und Ports prüfen.")
        }
    }

    static func object(_ text: String) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
            throw RobotConfigurationError("Ein JSON-Objekt wird erwartet.")
        }
        return value
    }

    func customPacket(_ text: String, values: [String: Any] = [:]) throws -> Data? {
        var value = try Self.object(text)
        if value.isEmpty { return nil }
        for key in ["topic", "service"] {
            if let name = value[key] as? String { value[key] = resolvedName(name) }
        }
        return try JSONSerialization.data(withJSONObject: Self.substitute(value, values: values))
    }

    func drivePacket(_ command: RobotDriveCommand) throws -> Data {
        let values = ["$forward": command.forward, "$sideways": command.sideways, "$rotation": -command.rotation]
        guard let packet = try customPacket(driveMessage, values: values) else {
            throw RobotConfigurationError("Fahrnachricht darf nicht leer sein.")
        }
        return packet
    }

    private static func substitute(_ value: Any, values: [String: Any]) -> Any {
        if let string = value as? String, let number = values[string] { return number }
        if let object = value as? [String: Any] { return object.mapValues { substitute($0, values: values) } }
        if let array = value as? [Any] { return array.map { substitute($0, values: values) } }
        return value
    }
}

struct RobotConfigurationError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

final class RobotConfigurationStore: ObservableObject {
    static let shared = RobotConfigurationStore()
    @Published private(set) var configuration: RobotConfiguration

    private static let key = "activeRobot.configuration"
    private static let secretService = "EdukARt.RobotSSH"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           var saved = try? JSONDecoder().decode(RobotConfiguration.self, from: data) {
            let defaults = RobotConfiguration.defaults
            let wasBlue3Default = saved.namespace == "eduard/blue3"
            if wasBlue3Default { saved.namespace = defaults.namespace }
            // Old container and ROS setup keys are ignored by Codable. The
            // installation target is now discovered from the live ROS graph.

            // The old drive editor contained only a ROS message body. Keep its
            // edited body, adding the previously stored topic and type once.
            if let body = try? RobotConfiguration.object(saved.driveMessage), body["kind"] == nil {
                let topic = saved.driveTopic == "cmd_vel" ? "cmd_vel" : saved.driveTopic
                saved.driveMessage = Self.json([
                    "kind": "publish", "topic": topic,
                    "messageType": saved.driveType, "message": body
                ]) ?? defaults.driveMessage
            }

            // With the old toggle off, these JSON fields were ignored. Convert
            // the actual legacy Eduard values without discarding edited fields.
            if !saved.useCustomCommands {
                for enabled in [true, false] {
                    let template = enabled ? defaults.enableAction : defaults.disableAction
                    if var action = try? RobotConfiguration.object(template) {
                        action["service"] = saved.modeService
                        action["serviceType"] = saved.modeServiceType
                        if var request = action["request"] as? [String: Any],
                           var mode = request["mode"] as? [String: Any] {
                            mode["mode"] = enabled ? saved.enabledMode : saved.disabledMode
                            mode["feature_mode"] = saved.featureMode
                            request["mode"] = mode
                            request["disable_feature"] = enabled ? saved.enabledDisableFeature : saved.disabledDisableFeature
                            action["request"] = request
                        }
                        if let text = Self.json(action) {
                            if enabled { saved.enableAction = text }
                            else { saved.disableAction = text }
                        }
                    }
                }
                if var action = try? RobotConfiguration.object(defaults.lightsAction) {
                    action["topic"] = saved.lightingTopic == "/eduard/blue3/set_lighting_color"
                        ? "set_lighting_color" : saved.lightingTopic
                    action["messageType"] = saved.lightingType
                    saved.lightsAction = Self.json(action) ?? defaults.lightsAction
                }
                saved.useCustomCommands = true
            }
            if wasBlue3Default {
                // Only rewrite the three former Eduard defaults. Keep every
                // edited message body and all other absolute ROS names.
                saved.driveMessage = Self.migrateBlue3Name(saved.driveMessage,
                                                            key: "topic", old: "/eduard/blue3/cmd_vel", new: "cmd_vel")
                saved.enableAction = Self.migrateBlue3Name(saved.enableAction,
                                                           key: "service", old: "/eduard/blue3/set_mode", new: "set_mode")
                saved.disableAction = Self.migrateBlue3Name(saved.disableAction,
                                                            key: "service", old: "/eduard/blue3/set_mode", new: "set_mode")
                saved.lightsAction = Self.migrateBlue3Name(saved.lightsAction,
                                                           key: "topic", old: "/eduard/blue3/set_lighting_color", new: "set_lighting_color")
            }
            configuration = saved
        } else {
            configuration = .defaults
        }
    }

    private static func json(_ object: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func migrateBlue3Name(_ text: String, key: String, old: String, new: String) -> String {
        guard var object = try? RobotConfiguration.object(text), object[key] as? String == old else {
            return text
        }
        object[key] = new
        return json(object) ?? text
    }

    func save(_ configuration: RobotConfiguration, password: String) throws {
        try configuration.validate()
        try Self.savePassword(password)
        UserDefaults.standard.set(try JSONEncoder().encode(configuration), forKey: Self.key)
        self.configuration = configuration
    }

    func reset() throws {
        try Self.deletePassword()
        try Self.deleteHostKey(host: configuration.host, port: configuration.sshPort)
        UserDefaults.standard.removeObject(forKey: Self.key)
        configuration = .defaults
    }

    var password: String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.secretService,
            kSecAttrAccount as String: "activeRobot",
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func savePassword(_ password: String) throws {
        if password.isEmpty { try deletePassword(); return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: secretService,
            kSecAttrAccount as String: "activeRobot"
        ]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: Data(password.utf8)] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data(password.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw RobotConfigurationError("SSH-Passwort konnte nicht gespeichert werden.") }
        } else if status != errSecSuccess {
            throw RobotConfigurationError("SSH-Passwort konnte nicht gespeichert werden.")
        }
    }

    private static func deleteHostKey(host: String, port: Int) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: secretService,
            kSecAttrAccount as String: "hostkey.\(host):\(port)"
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RobotConfigurationError("SSH-Hostschlüssel konnte nicht gelöscht werden.")
        }
    }

    private static func deletePassword() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: secretService,
            kSecAttrAccount as String: "activeRobot"
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RobotConfigurationError("SSH-Passwort konnte nicht gelöscht werden.")
        }
    }
}
