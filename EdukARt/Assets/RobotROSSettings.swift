import Foundation

/// Shared persisted ROS inputs. Defaults match the existing Eduard commands.
enum RobotROSSettings {
    static var activeStore: UserDefaults? {
        RobotProfileStore.shared.selectedSettings
    }

    enum TextField: String, CaseIterable {
        case namespace
        case driveTopic
        case driveMessageType
        case modeService
        case modeServiceType
        case lightingTopic
        case lightingMessageType
        case allLights
        case leftLights
        case rightLights

        var key: String { "robotROS." + rawValue }

        var title: String {
            switch self {
            case .namespace: return "Namespace:"
            case .driveTopic: return "Topic"
            case .driveMessageType: return "Message type"
            case .modeService: return "Service"
            case .modeServiceType: return "Service type"
            case .lightingTopic: return "Topic"
            case .lightingMessageType: return "Message type"
            case .allLights: return "All lights"
            case .leftLights: return "Left lights"
            case .rightLights: return "Right lights"
            }
        }

        var defaultValue: String {
            switch self {
            case .namespace: return "eduard/blue3"
            case .driveTopic: return "cmd_vel"
            case .driveMessageType: return "geometry_msgs/msg/Twist"
            case .modeService: return "set_mode"
            case .modeServiceType: return "edu_robot/srv/SetMode"
            case .lightingTopic: return "set_lighting_color"
            case .lightingMessageType: return "edu_robot/msg/SetLightingColor"
            case .allLights: return "all"
            case .leftLights: return "left_side"
            case .rightLights: return "right_side"
            }
        }

        var value: String {
            RobotROSSettings.activeStore?.string(forKey: key) ?? defaultValue
        }
    }

    enum NumberField: String, CaseIterable {
        case enabledMode
        case disabledMode
        case mecanum
        case offroad
        case featureMode
        case enabledDisableFeature
        case disabledDisableFeature
        case lightOff
        case lightDim
        case lightFlash
        case lightPulsation
        case lightRotation
        case lightRunning

        var key: String { "robotROS." + rawValue }

        var defaultValue: Int {
            switch self {
            case .enabledMode: return 2
            case .disabledMode: return 0
            case .mecanum: return 2
            case .offroad: return 1
            case .featureMode: return 0
            case .enabledDisableFeature: return 0
            case .disabledDisableFeature: return 1
            case .lightOff: return 0
            case .lightDim: return 1
            case .lightFlash: return 2
            case .lightPulsation: return 3
            case .lightRotation: return 4
            case .lightRunning: return 5
            }
        }

        var value: Int {
            (RobotROSSettings.activeStore?.object(forKey: key) as? Int) ?? defaultValue
        }
    }

    /// Absolute names override the namespace; relative names use the configured robot.
    static func resolvedName(_ name: String, namespace: String = TextField.namespace.value) -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasPrefix("/") { return name }
        let namespace = namespace
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/")
            .joined(separator: "/")
        return "/" + (namespace.isEmpty ? "" : namespace + "/") + name
    }
}
