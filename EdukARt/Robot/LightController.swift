//
//  LightController.swift
//  EdukARt
//
//  - Wraps Eduard's ROS2 lighting topic.
//  - Sends only lighting messages and leaves driving or enable/disable state untouched.
//

import Combine
import Foundation

// ToDo: Rainbow Solid und Solid Color mode auf FIrmware implementieren: https://github.com/EduArt-Robotik/firmware_iot_lighting/blob/764625785a8b2b5ef00ba80a48bdabd500e718a1/Core/Src/main.c#L499-L636

final class LightController: ObservableObject {
    enum StandardMode: String, CaseIterable, Identifiable {
        // Factory modes that are currently not exposed as buttons:
        // - dimmed: white DIM light
        // - beam: white DIM/high-beam style light
        case dimmed
        case enabled
        case loading
        case connectionLost
        case beam
        case flashLeft
        case flashRight
        case rotation
        case running
        case solid
        case rainbow
        case rainbowSolid

        var id: String {
            rawValue
        }

        static let visibleModes: [StandardMode] = [
            .enabled,
            .loading,
            .connectionLost,
            .rotation,
            .solid,
            .rainbow,
            .flashLeft,
            .flashRight,
            .running
        ]

        static let allLightsModes: [StandardMode] = [
            .connectionLost,
            .rotation,
            .running,
            .solid,
            .rainbow,
            .rainbowSolid
        ]

        var title: String {
            switch self {
            case .dimmed:
                return "Dimmed Light"
            case .enabled:
                return "Enabled Light"
            case .loading:
                return "Pulsation"
            case .connectionLost:
                return "Slow Blinking"
            case .beam:
                return "High Beam"
            case .flashLeft:
                return "Left Signal"
            case .flashRight:
                return "Right Signal"
            case .rotation:
                return "Fast Blinking"
            case .running:
                return "Running Light"
            case .solid:
                return "Solid Color"
            case .rainbow:
                return "Rainbow Running"
            case .rainbowSolid:
                return "Rainbow Solid"
            }
        }

        var systemImageName: String {
            switch self {
            case .dimmed:
                return "lightbulb"
            case .enabled:
                return "checkmark.circle"
            case .loading:
                return "hourglass"
            case .connectionLost:
                return "exclamationmark.triangle"
            case .beam:
                return "light.high.beam"
            case .flashLeft:
                return "arrowtriangle.left.fill"
            case .flashRight:
                return "arrowtriangle.right.fill"
            case .rotation:
                return "rotate.3d"
            case .running:
                return "camera.filters"
            case .solid:
                return "circle.fill"
            case .rainbow:
                return "camera.filters"
            case .rainbowSolid:
                return "paintpalette"
            }
        }

        var isFirmwareImplemented: Bool {
            switch self {
            case .solid, .rainbowSolid:
                return false
            case .dimmed, .enabled, .loading, .connectionLost, .beam, .flashLeft, .flashRight, .rotation, .running, .rainbow:
                return true
            }
        }

        func lightingCommands(allLightsColor: RGBColor, signalColor: RGBColor) -> [LightingCommand] {
            switch self {
            case .dimmed:
                return [
                    LightingCommand(
                        lightingName: LightingGroup.all,
                        red: 255,
                        green: 255,
                        blue: 255,
                        brightness: 0.35,
                        mode: .dim
                    )
                ]
            case .enabled:
                return [
                    LightingCommand(
                        lightingName: LightingGroup.all,
                        red: 255,
                        green: 255,
                        blue: 255,
                        brightness: 1.0,
                        mode: .dim
                    )
                ]
            case .loading:
                return [
                    LightingCommand(
                        lightingName: LightingGroup.all,
                        red: 255,
                        green: 255,
                        blue: 255,
                        brightness: 1.0,
                        mode: .pulsation
                    )
                ]
            case .connectionLost:
                return [
                    LightingCommand(
                        lightingName: LightingGroup.all,
                        red: allLightsColor.red,
                        green: allLightsColor.green,
                        blue: allLightsColor.blue,
                        brightness: 1.0,
                        mode: .flash
                    )
                ]
            case .beam:
                return [
                    LightingCommand(
                        lightingName: LightingGroup.all,
                        red: 255,
                        green: 255,
                        blue: 255,
                        brightness: 1.0,
                        mode: .dim
                    )
                ]
            case .flashLeft:
                return [
                    LightingCommand(
                        lightingName: LightingGroup.leftSide,
                        red: signalColor.red,
                        green: signalColor.green,
                        blue: signalColor.blue,
                        brightness: 1.0,
                        mode: .flash
                    )
                ]
            case .flashRight:
                return [
                    LightingCommand(
                        lightingName: LightingGroup.rightSide,
                        red: signalColor.red,
                        green: signalColor.green,
                        blue: signalColor.blue,
                        brightness: 1.0,
                        mode: .flash
                    )
                ]
            case .rotation:
                return [
                    LightingCommand(
                        lightingName: LightingGroup.all,
                        red: allLightsColor.red,
                        green: allLightsColor.green,
                        blue: allLightsColor.blue,
                        brightness: 1.0,
                        mode: .rotation
                    )
                ]
            case .running:
                return [
                    LightingCommand(
                        lightingName: LightingGroup.all,
                        red: allLightsColor.red,
                        green: allLightsColor.green,
                        blue: allLightsColor.blue,
                        brightness: 1.0,
                        mode: .running
                    )
                ]
            case .solid:
                return [
                    LightingCommand(
                        lightingName: LightingGroup.all,
                        red: allLightsColor.red,
                        green: allLightsColor.green,
                        blue: allLightsColor.blue,
                        brightness: 1.0,
                        mode: .dim
                    )
                ]
            case .rainbow, .rainbowSolid:
                return []
            }
        }

    }

    struct LightingCommand {
        let lightingName: String
        let red: Int
        let green: Int
        let blue: Int
        let brightness: Double
        let mode: LightingMode
    }

    struct RGBColor: Equatable {
        let red: Int
        let green: Int
        let blue: Int
    }

    enum LightingMode: Int {
        case off = 0
        case dim = 1
        case flash = 2
        case pulsation = 3
        case rotation = 4
        case running = 5
    }

    enum LightingGroup {
        static let all = "all"
        static let leftSide = "left_side"
        static let rightSide = "right_side"
    }

    @Published private(set) var activeMode: StandardMode = .dimmed
    @Published private(set) var allLightsColor = RGBColor(red: 255, green: 136, blue: 0)
    @Published private(set) var signalColor = RGBColor(red: 255, green: 136, blue: 0)

    private let transport: EduardROSCommandTransport
    private let lightingTopic = "/eduard/blue3/set_lighting_color"
    private let lightingMessageType = "edu_robot/msg/SetLightingColor"
    private let rainbowInterval = 0.18

    private var rainbowTimer: Timer?
    private var rainbowHue = 0.0
    private var activeRainbowMode: LightingMode = .running

    init(transport: EduardROSCommandTransport) {
        self.transport = transport
    }

    deinit {
        rainbowTimer?.invalidate()
    }

    func send(_ mode: StandardMode) {
        activeMode = mode

        if mode == .rainbow || mode == .rainbowSolid {
            startRainbow(mode: mode == .rainbow ? .running : .dim)
            return
        }

        stopRainbow()
        mode.lightingCommands(
            allLightsColor: allLightsColor,
            signalColor: signalColor
        ).forEach(sendLightingCommand)
    }

    func setAllLightsColor(red: Int, green: Int, blue: Int) {
        allLightsColor = RGBColor(
            red: clampedColorComponent(red),
            green: clampedColorComponent(green),
            blue: clampedColorComponent(blue)
        )

        guard StandardMode.allLightsModes.contains(activeMode) else {
            return
        }

        send(activeMode)
    }

    func setSignalColor(red: Int, green: Int, blue: Int) {
        signalColor = RGBColor(
            red: clampedColorComponent(red),
            green: clampedColorComponent(green),
            blue: clampedColorComponent(blue)
        )

        guard activeMode == .flashLeft || activeMode == .flashRight else {
            return
        }

        send(activeMode)
    }

    func stop() {
        send(.dimmed)
    }

    private func sendLightingCommand(_ command: LightingCommand) {
        transport.send(
            topic: lightingTopic,
            messageType: lightingMessageType,
            message: [
                "lighting_name": .string(command.lightingName),
                "r": .int(command.red),
                "g": .int(command.green),
                "b": .int(command.blue),
                "brightness": .object([
                    "data": .double(command.brightness)
                ]),
                "mode": .int(command.mode.rawValue)
            ]
        )
    }

    private func clampedColorComponent(_ value: Int) -> Int {
        min(max(value, 0), 255)
    }

    private func startRainbow(mode: LightingMode) {
        stopRainbow()
        activeRainbowMode = mode
        sendRainbowStep()

        rainbowTimer = Timer.scheduledTimer(withTimeInterval: rainbowInterval, repeats: true) { [weak self] _ in
            self?.sendRainbowStep()
        }
    }

    private func stopRainbow() {
        rainbowTimer?.invalidate()
        rainbowTimer = nil
    }

    private func sendRainbowStep() {
        let color = rgbColor(hue: rainbowHue, saturation: 1.0, brightness: 1.0)
        rainbowHue = (rainbowHue + 0.025).truncatingRemainder(dividingBy: 1.0)

        sendLightingCommand(
            LightingCommand(
                lightingName: LightingGroup.all,
                red: color.red,
                green: color.green,
                blue: color.blue,
                brightness: 1.0,
                mode: activeRainbowMode
            )
        )
    }

    private func rgbColor(hue: Double, saturation: Double, brightness: Double) -> RGBColor {
        let scaledHue = hue * 6.0
        let sector = Int(scaledHue)
        let fraction = scaledHue - Double(sector)
        let p = brightness * (1.0 - saturation)
        let q = brightness * (1.0 - fraction * saturation)
        let t = brightness * (1.0 - (1.0 - fraction) * saturation)

        let components: (red: Double, green: Double, blue: Double)
        switch sector % 6 {
        case 0:
            components = (brightness, t, p)
        case 1:
            components = (q, brightness, p)
        case 2:
            components = (p, brightness, t)
        case 3:
            components = (p, q, brightness)
        case 4:
            components = (t, p, brightness)
        default:
            components = (brightness, p, q)
        }

        return RGBColor(
            red: Int((components.red * 255.0).rounded()),
            green: Int((components.green * 255.0).rounded()),
            blue: Int((components.blue * 255.0).rounded())
        )
    }
}
