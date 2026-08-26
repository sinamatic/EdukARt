//
//  Eduard.swift
//  EdukARt-Rebuild
//
//  Represents the physical Eduard robot.
//  Contains all Eduard-specific ROS commands,
//  including movement, operating mode and lighting.
//

import Foundation


final class Eduard {

    // ======================================================
    // MARK: - Light Mode
    // ======================================================

    enum LightMode:
        String,
        CaseIterable,
        Identifiable {

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


        static let visibleModes: [LightMode] = [
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


        static let allLightsModes: [LightMode] = [
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

            case .solid,
                 .rainbowSolid:

                return false


            default:

                return true
            }
        }
    }


    // ======================================================
    // MARK: - Lighting Types
    // ======================================================

    private struct RGBColor {

        let red: Int
        let green: Int
        let blue: Int
    }


    private enum LightingMode:
        Int {

        case off = 0
        case dim = 1
        case flash = 2
        case pulsation = 3
        case rotation = 4
        case running = 5
    }


    private struct LightingCommand {

        let lightingName: String

        let red: Int
        let green: Int
        let blue: Int

        let brightness: Double

        let mode:
            LightingMode
    }


    private enum LightingGroup {

        static let all =
            "all"

        static let leftSide =
            "left_side"

        static let rightSide =
            "right_side"
    }


    // ======================================================
    // MARK: - ROS
    // ======================================================

    private let setModeService =
        "set_mode"

    private let driveVelocityTopic =
        "cmd_vel"

    private let lightingTopic =
        "/eduard/blue3/set_lighting_color"

    private let lightingMessageType =
        "edu_robot/msg/SetLightingColor"


    // ======================================================
    // MARK: - Values
    // ======================================================

    private let remoteControlledModeValue =
        2.0

    private let disabledModeValue =
        0.0


    // ======================================================
    // MARK: - Light State
    // ======================================================

    private(set) var activeLightMode:
        LightMode = .dimmed

    private var allLightsColor =
        RGBColor(
            red: 255,
            green: 136,
            blue: 0
        )

    private var signalColor =
        RGBColor(
            red: 255,
            green: 136,
            blue: 0
        )


    private let rainbowInterval =
        0.18

    private var rainbowTimer:
        Timer?

    private var rainbowHue =
        0.0

    private var activeRainbowMode:
        LightingMode = .running


    // ======================================================
    // MARK: - Communication
    // ======================================================
    //
    // The existing Eduard ROS/UDP sender will be inserted
    // here once its current implementation is available.
    //
    // It needs to provide:
    //
    // send(
    //     topic: String,
    //     messageType: String,
    //     message: ...
    // )
    //
    // call(
    //     service: String,
    //     serviceType: String,
    //     request: ...
    // )
    //
    // ======================================================


    deinit {

        rainbowTimer?
            .invalidate()
    }


    // ======================================================
    // MARK: - Enable / Disable
    // ======================================================

    func setEnabled(
        _ enabled: Bool,
        driveMode: RobotDriveMode
    ) {

        if enabled == false {
            stop()
        }


        call(
            service:
                setModeService,

            serviceType:
                "edu_robot/srv/SetMode",

            request: [

                "mode": [

                    "mode":
                        enabled
                        ? remoteControlledModeValue
                        : disabledModeValue,

                    "drive_kinematic":
                        driveMode
                            .driveKinematicValue,

                    "feature_mode":
                        0
                ],

                "disable_feature":
                    enabled
                    ? 0
                    : 1
            ]
        )


        if enabled {
            stop()
        }
    }


    // ======================================================
    // MARK: - Drive
    // ======================================================

    func drive(
        _ command:
            RobotDriveCommand
    ) {

        send(
            topic:
                driveVelocityTopic,

            messageType:
                "geometry_msgs/msg/Twist",

            message: [

                "linear": [

                    "x":
                        command.forward,

                    "y":
                        command.sideways,

                    "z":
                        0
                ],

                "angular": [

                    "x":
                        0,

                    "y":
                        0,

                    "z":
                        command.rotation
                ]
            ]
        )
    }


    // MARK: - Stop

    func stop() {

        drive(
            .stop
        )
    }


    // ======================================================
    // MARK: - Lights
    // ======================================================

    func setLightMode(
        _ mode:
            LightMode
    ) {

        activeLightMode =
            mode


        if mode == .rainbow
            || mode == .rainbowSolid {

            startRainbow(
                mode:
                    mode == .rainbow
                    ? .running
                    : .dim
            )

            return
        }


        stopRainbow()


        lightingCommands(
            for:
                mode
        )
        .forEach(
            sendLightingCommand
        )
    }


    func setAllLightsColor(
        red: Int,
        green: Int,
        blue: Int
    ) {

        allLightsColor =
            RGBColor(
                red:
                    clampedColorComponent(
                        red
                    ),

                green:
                    clampedColorComponent(
                        green
                    ),

                blue:
                    clampedColorComponent(
                        blue
                    )
            )


        guard LightMode
                .allLightsModes
                .contains(
                    activeLightMode
                )

        else {
            return
        }


        setLightMode(
            activeLightMode
        )
    }


    func setSignalColor(
        red: Int,
        green: Int,
        blue: Int
    ) {

        signalColor =
            RGBColor(
                red:
                    clampedColorComponent(
                        red
                    ),

                green:
                    clampedColorComponent(
                        green
                    ),

                blue:
                    clampedColorComponent(
                        blue
                    )
            )


        guard activeLightMode == .flashLeft
                || activeLightMode == .flashRight

        else {
            return
        }


        setLightMode(
            activeLightMode
        )
    }


    // ======================================================
    // MARK: - Lighting Commands
    // ======================================================

    private func lightingCommands(
        for mode:
            LightMode
    ) -> [LightingCommand] {

        switch mode {


        case .dimmed:

            return [
                LightingCommand(
                    lightingName:
                        LightingGroup.all,

                    red: 255,
                    green: 255,
                    blue: 255,

                    brightness:
                        0.35,

                    mode:
                        .dim
                )
            ]


        case .enabled,
             .beam:

            return [
                LightingCommand(
                    lightingName:
                        LightingGroup.all,

                    red: 255,
                    green: 255,
                    blue: 255,

                    brightness:
                        1,

                    mode:
                        .dim
                )
            ]


        case .loading:

            return [
                LightingCommand(
                    lightingName:
                        LightingGroup.all,

                    red: 255,
                    green: 255,
                    blue: 255,

                    brightness:
                        1,

                    mode:
                        .pulsation
                )
            ]


        case .connectionLost:

            return [
                lightingCommand(
                    group:
                        LightingGroup.all,

                    color:
                        allLightsColor,

                    mode:
                        .flash
                )
            ]


        case .flashLeft:

            return [
                lightingCommand(
                    group:
                        LightingGroup.leftSide,

                    color:
                        signalColor,

                    mode:
                        .flash
                )
            ]


        case .flashRight:

            return [
                lightingCommand(
                    group:
                        LightingGroup.rightSide,

                    color:
                        signalColor,

                    mode:
                        .flash
                )
            ]


        case .rotation:

            return [
                lightingCommand(
                    group:
                        LightingGroup.all,

                    color:
                        allLightsColor,

                    mode:
                        .rotation
                )
            ]


        case .running:

            return [
                lightingCommand(
                    group:
                        LightingGroup.all,

                    color:
                        allLightsColor,

                    mode:
                        .running
                )
            ]


        case .solid:

            return [
                lightingCommand(
                    group:
                        LightingGroup.all,

                    color:
                        allLightsColor,

                    mode:
                        .dim
                )
            ]


        case .rainbow,
             .rainbowSolid:

            return []
        }
    }


    private func lightingCommand(
        group: String,
        color: RGBColor,
        mode: LightingMode
    ) -> LightingCommand {

        LightingCommand(
            lightingName:
                group,

            red:
                color.red,

            green:
                color.green,

            blue:
                color.blue,

            brightness:
                1,

            mode:
                mode
        )
    }


    private func sendLightingCommand(
        _ command:
            LightingCommand
    ) {

        send(
            topic:
                lightingTopic,

            messageType:
                lightingMessageType,

            message: [

                "lighting_name":
                    command.lightingName,

                "r":
                    command.red,

                "g":
                    command.green,

                "b":
                    command.blue,

                "brightness": [
                    "data":
                        command.brightness
                ],

                "mode":
                    command.mode.rawValue
            ]
        )
    }
    



    // ======================================================
    // MARK: - Rainbow
    // ======================================================

    private func startRainbow(
        mode:
            LightingMode
    ) {

        stopRainbow()

        activeRainbowMode =
            mode

        sendRainbowStep()


        rainbowTimer =
            Timer.scheduledTimer(
                withTimeInterval:
                    rainbowInterval,

                repeats:
                    true
            ) { [weak self] _ in

                self?
                    .sendRainbowStep()
            }
    }


    private func stopRainbow() {

        rainbowTimer?
            .invalidate()

        rainbowTimer =
            nil
    }


    private func sendRainbowStep() {

        let color =
            rgbColor(
                hue:
                    rainbowHue
            )


        rainbowHue =
            (
                rainbowHue
                + 0.025
            )
            .truncatingRemainder(
                dividingBy:
                    1
            )


        sendLightingCommand(
            LightingCommand(
                lightingName:
                    LightingGroup.all,

                red:
                    color.red,

                green:
                    color.green,

                blue:
                    color.blue,

                brightness:
                    1,

                mode:
                    activeRainbowMode
            )
        )
        
    }
    
    
    // MARK: - Stop Lights

    func stopLights() {

        stopRainbow()
    }
    
    


    // ======================================================
    // MARK: - Color Helpers
    // ======================================================

    private func clampedColorComponent(
        _ value: Int
    ) -> Int {

        min(
            max(
                value,
                0
            ),
            255
        )
    }


    private func rgbColor(
        hue: Double
    ) -> RGBColor {

        let saturation =
            1.0

        let brightness =
            1.0


        let scaledHue =
            hue * 6

        let sector =
            Int(
                scaledHue
            )

        let fraction =
            scaledHue
            - Double(
                sector
            )


        let p =
            brightness
            * (
                1
                - saturation
            )

        let q =
            brightness
            * (
                1
                - fraction
                * saturation
            )

        let t =
            brightness
            * (
                1
                - (
                    1
                    - fraction
                )
                * saturation
            )


        let components:
            (
                red: Double,
                green: Double,
                blue: Double
            )


        switch sector % 6 {

        case 0:

            components =
                (
                    brightness,
                    t,
                    p
                )

        case 1:

            components =
                (
                    q,
                    brightness,
                    p
                )

        case 2:

            components =
                (
                    p,
                    brightness,
                    t
                )

        case 3:

            components =
                (
                    p,
                    q,
                    brightness
                )

        case 4:

            components =
                (
                    t,
                    p,
                    brightness
                )

        default:

            components =
                (
                    brightness,
                    p,
                    q
                )
        }


        return RGBColor(
            red:
                Int(
                    (
                        components.red
                        * 255
                    )
                    .rounded()
                ),

            green:
                Int(
                    (
                        components.green
                        * 255
                    )
                    .rounded()
                ),

            blue:
                Int(
                    (
                        components.blue
                        * 255
                    )
                    .rounded()
                )
        )
        
        
        
    }


    // ======================================================
    // MARK: - ROS Transport
    // ======================================================
    //
    // IMPORTANT:
    //
    // These two functions are intentionally left as the
    // only missing low-level part.
    //
    // Your old project used EduardROSCommandTransport here,
    // but its implementation is not contained in the
    // available source material.
    //
    // Paste the existing transport implementation here
    // rather than recreating its UDP packet format.
    // ======================================================

    private func send(
        topic: String,
        messageType: String,
        message: [String: Any]
    ) {

        // Existing UDP/ROS transport goes here.
    }


    private func call(
        service: String,
        serviceType: String,
        request: [String: Any]
    ) {

        // Existing UDP/ROS transport goes here.
    }
}
