
import Foundation

struct RobotSetupConfiguration: Codable, Equatable {
    var host = "192.168.8.100"
    var sshPort = "22"
    var username = "user"
    var udpPort = "50505"
    var container = "sml_navigation_move_base"
    var setup = "source /opt/ros/jazzy/setup.bash"
    var environment = "{}"
    var namespace = "autonohm/sml_bot"
    var driveTopic = "cmd_vel"
    var driveType = "geometry_msgs/msg/Twist"
    var driveMessage = """
    {
      "linear": {"x": "$forward", "y": "$sideways", "z": 0},
      "angular": {"x": 0, "y": 0, "z": "$rotation"}
    }
    """
    var enableAction = """
    {"kind":"service","service":"enable","serviceType":"std_srvs/srv/SetBool","request":{"data":true}}
    """
    var disableAction = """
    {"kind":"service","service":"enable","serviceType":"std_srvs/srv/SetBool","request":{"data":false}}
    """
    var lightsAction = "{}"
    var report = ""
    var lastDiscovery = ""

    static let key = "robotSetup.configuration"

    static func load(from store: UserDefaults) -> Self? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    func save(to store: UserDefaults) throws {
        try validate()
        store.set(try JSONEncoder().encode(self), forKey: Self.key)
    }

    func validateConnection() throws {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !username.isEmpty,
              let ssh = UInt16(sshPort), ssh > 0,
              let udp = UInt16(udpPort), udp > 0 else {
            throw RobotSetupError("Bitte Host, Benutzer und gültige Ports (1–65535) eintragen.")
        }
    }

    func validate() throws {
        try validateConnection()
        guard !driveTopic.isEmpty, driveType.contains("/msg/") else {
            throw RobotSetupError("Fahrtopic und ROS-2-Message-Typ fehlen.")
        }
        _ = try Self.object(driveMessage)
        for action in [enableAction, disableAction, lightsAction] {
            let object = try Self.object(action)
            if object.isEmpty { continue }
            let service = object["kind"] as? String == "service"
            guard let name = object[service ? "service" : "topic"] as? String, !name.isEmpty,
                  let type = object[service ? "serviceType" : "messageType"] as? String,
                  type.contains(service ? "/srv/" : "/msg/"),
                  object[service ? "request" : "message"] is [String: Any] else {
                throw RobotSetupError("Aktion benötigt Topic/Service, Typ und message/request als JSON-Objekt. {} deaktiviert sie.")
            }
        }
        let variables = try Self.object(environment)
        guard variables.allSatisfy({ key, value in
            key.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil && value is String
        }) else {
            throw RobotSetupError("Umgebung muss ein JSON-Objekt mit Variablennamen und Textwerten sein.")
        }
    }

    mutating func formatJSONFields() {
        driveMessage = Self.readableJSON(driveMessage)
        enableAction = Self.readableJSON(enableAction)
        disableAction = Self.readableJSON(disableAction)
        lightsAction = Self.readableJSON(lightsAction)
        environment = Self.readableJSON(environment)
        report = Self.readableJSON(report)
    }

    private static func readableJSON(_ text: String) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return text }
        return String(decoding: data, as: UTF8.self)
    }

    static func object(_ text: String) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
            throw RobotSetupError("Ein JSON-Objekt wird erwartet.")
        }
        return object
    }

    func name(_ value: String) -> String {
        if value.hasPrefix("/") { return value }
        return "/" + ([namespace, value].filter { !$0.isEmpty }.joined(separator: "/"))
            .split(separator: "/").joined(separator: "/")
    }

    func actionData(_ text: String, values: [String: Double] = [:]) throws -> Data? {
        var object = try Self.object(text)
        if object.isEmpty { return nil }
        for key in ["topic", "service"] {
            if let value = object[key] as? String { object[key] = name(value) }
        }
        return try JSONSerialization.data(withJSONObject: Self.substitute(object, values: values), options: [.withoutEscapingSlashes])
    }

    func driveData(_ command: RobotDriveCommand) throws -> Data {
        let message = try Self.object(driveMessage)
        let values = ["$forward": command.forward, "$sideways": command.sideways, "$rotation": -command.rotation]
        return try JSONSerialization.data(withJSONObject: [
            "kind": "publish", "topic": name(driveTopic), "messageType": driveType,
            "message": Self.substitute(message, values: values)
        ], options: [.withoutEscapingSlashes])
    }

    private static func substitute(_ value: Any, values: [String: Double]) -> Any {
        if let text = value as? String, let number = values[text] { return number }
        if let object = value as? [String: Any] { return object.mapValues { substitute($0, values: values) } }
        if let array = value as? [Any] { return array.map { substitute($0, values: values) } }
        return value
    }
}

struct RobotSetupError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
