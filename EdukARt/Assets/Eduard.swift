//
//  Eduard.swift
//  EdukARt-Rebuild
//
//  Represents the physical Eduard robot.
//  Contains all Eduard-specific ROS commands,
//  including movement, operating mode and lighting.
//

import Foundation
import Network
import pingx


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
        case slowBlinking
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
            .slowBlinking,
            .rotation,
            .solid,
            .rainbow,
            .flashLeft,
            .flashRight,
            .running
        ]


        static let allLightsModes: [LightMode] = [
            .slowBlinking,
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

            case .slowBlinking:
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

            case .slowBlinking:
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

        var configuredValue: Int {
            switch self {
            case .off: return RobotROSSettings.NumberField.lightOff.value
            case .dim: return RobotROSSettings.NumberField.lightDim.value
            case .flash: return RobotROSSettings.NumberField.lightFlash.value
            case .pulsation: return RobotROSSettings.NumberField.lightPulsation.value
            case .rotation: return RobotROSSettings.NumberField.lightRotation.value
            case .running: return RobotROSSettings.NumberField.lightRunning.value
            }
        }
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

        static var all: String {
            RobotROSSettings.TextField.allLights.value
        }

        static var leftSide: String {
            RobotROSSettings.TextField.leftLights.value
        }

        static var rightSide: String {
            RobotROSSettings.TextField.rightLights.value
        }
    }


    // ======================================================
    // MARK: - ROS
    // ======================================================

    private var setModeService: String {
        RobotROSSettings.resolvedName(RobotROSSettings.TextField.modeService.value)
    }

    private var driveVelocityTopic: String {
        RobotROSSettings.resolvedName(RobotROSSettings.TextField.driveTopic.value)
    }

    private var lightingTopic: String {
        RobotROSSettings.resolvedName(RobotROSSettings.TextField.lightingTopic.value)
    }

    private var lightingMessageType: String {
        RobotROSSettings.TextField.lightingMessageType.value
    }


    
    // ======================================================
    // MARK: - ROS Value
    // ======================================================

    private indirect enum ROSValue:
        Encodable {

        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([ROSValue])
        case object([String: ROSValue])


        func encode(
            to encoder: Encoder
        ) throws {

            var container =
                encoder.singleValueContainer()


            switch self {

            case .bool(let value):
                try container.encode(value)

            case .int(let value):
                try container.encode(value)

            case .double(let value):
                try container.encode(value)

            case .string(let value):
                try container.encode(value)

            case .array(let value):
                try container.encode(value)

            case .object(let value):
                try container.encode(value)
            }
        }
    }


    // ======================================================
    // MARK: - ROS Commands
    // ======================================================

    private struct ROSPublishCommand:
        Encodable {

        let kind =
            "publish"

        let topic:
            String

        let messageType:
            String

        let message:
            [String: ROSValue]
    }


    private struct ROSServiceCommand:
        Encodable {

        let kind =
            "service"

        let service:
            String

        let serviceType:
            String

        let request:
            [String: ROSValue]
    }
    
    // ======================================================
    // MARK: - Values
    // ======================================================

    private var remoteControlledModeValue: Double {
        Double(RobotROSSettings.NumberField.enabledMode.value)
    }

    private var disabledModeValue: Double {
        Double(RobotROSSettings.NumberField.disabledMode.value)
    }


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

    var activeAllLightsColor:
        (red: Int, green: Int, blue: Int) {

        (
            allLightsColor.red,
            allLightsColor.green,
            allLightsColor.blue
        )
    }

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
    
    
    // MARK: - Init

    init() {
        robotConfiguration = RobotROSSettings.activeStore.flatMap { RobotSetupConfiguration.load(from: $0) }
        targetHost = robotConfiguration?.host ?? "192.168.0.100"
        targetPort = robotConfiguration.flatMap { UInt16($0.udpPort) } ?? 50505

        let endpointHost =
            NWEndpoint.Host(
                targetHost
            )

        let endpointPort =
            NWEndpoint.Port(
                rawValue:
                    targetPort
            )
            ?? 50505


        connection =
            NWConnection(
                host:
                    endpointHost,

                port:
                    endpointPort,

                using:
                    .udp
            )


        connection.start(
            queue:
                .global(
                    qos:
                        .userInitiated
                )
        )
    }


    // ======================================================
    // MARK: - UDP Transport
    // ======================================================

    var onBridgeStatus: ((String) -> Void)?
    var usesConfiguredBridge: Bool { robotConfiguration != nil }
    private var pendingEnable: (id: String, completion: (Result<Void, Error>) -> Void)?
    private var robotConfiguration: RobotSetupConfiguration?
    private var targetHost = "192.168.0.100"
    private var targetPort: UInt16 = 50505

    private var connection:
        NWConnection

    private let connectionPinger =
        Pinger()

    private let encoder =
        JSONEncoder()

    deinit {

        rainbowTimer?
            .invalidate()

        connection.cancel()
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


        if let config = robotConfiguration {
            if let data = try? config.actionData(enabled ? config.enableAction : config.disableAction) {
                sendConfiguredData(data)
            }
            if enabled { stop() }
            return
        }

        if RobotROSSettings.Block.operatingMode.isEnabled {
            call(
                service:
                    setModeService,

                serviceType:
                    RobotROSSettings.TextField.modeServiceType.value,

                request: [

                    "mode":
                        .object([

                            "mode":
                                .double(
                                    enabled
                                    ? remoteControlledModeValue
                                    : disabledModeValue
                                ),

                            "drive_kinematic":
                                .double(
                                    driveMode
                                        .driveKinematicValue
                                ),

                            "feature_mode":
                                .double(Double(RobotROSSettings.NumberField.featureMode.value))
                        ]),

                    "disable_feature":
                        .double(
                            enabled
                            ? Double(RobotROSSettings.NumberField.enabledDisableFeature.value)
                            : Double(RobotROSSettings.NumberField.disabledDisableFeature.value)
                        )
                ]
            )

        }

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
        if let config = robotConfiguration {
            if let data = try? config.driveData(command) { sendConfiguredData(data) }
            return
        }

        send(
            topic:
                driveVelocityTopic,

            messageType:
                RobotROSSettings.TextField.driveMessageType.value,

            message: [

                "linear":
                    .object([

                        "x":
                            .double(
                                command.forward
                            ),

                        "y":
                            .double(
                                command.sideways
                            ),

                        "z":
                            .double(0)
                    ]),

                "angular":
                    .object([

                        "x":
                            .double(0),

                        "y":
                            .double(0),

                        "z":
                            .double(
                                -command.rotation
                            )
                    ])
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


        case .slowBlinking:

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
        if let config = robotConfiguration {
            let values = ["$red": Double(command.red), "$green": Double(command.green),
                          "$blue": Double(command.blue), "$brightness": command.brightness,
                          "$mode": Double(command.mode.configuredValue)]
            if let data = try? config.actionData(config.lightsAction, values: values) { sendConfiguredData(data) }
            return
        }
        guard RobotROSSettings.Block.lights.isEnabled else { return }

        send(
            topic:
                lightingTopic,

            messageType:
                lightingMessageType,

            message: [

                "lighting_name":
                    .string(command.lightingName),

                "r":
                    .int(command.red),

                "g":
                    .int(command.green),

                "b":
                    .int(command.blue),

                "brightness": .object([
                    "data":
                        .double(command.brightness)
                ]),

                "mode":
                    .int(command.mode.configuredValue)
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


    func stopLightAnimation() {
        stopRainbow()
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
    
    

    func reconnect() {
        pendingEnable = nil
        robotConfiguration = RobotROSSettings.activeStore.flatMap { RobotSetupConfiguration.load(from: $0) }
        targetHost = robotConfiguration?.host ?? "192.168.0.100"
        targetPort = robotConfiguration.flatMap { UInt16($0.udpPort) } ?? 50505

        connection.cancel()

        connection =
            makeConnection()

        connection.start(
            queue:
                .global(
                    qos:
                        .userInitiated
                )
        )
    }

    func enableConfiguredRobot(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let config = robotConfiguration else { return }
        receiveBridgeReply(on: connection)
        do {
            guard let data = try config.actionData(config.enableAction),
                  var packet = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw RobotSetupError("Keine Freigabe-Aktion konfiguriert.")
            }
            let id = UUID().uuidString
            packet["id"] = id
            pendingEnable = (id, completion)
            sendConfiguredData(try JSONSerialization.data(withJSONObject: packet, options: [.withoutEscapingSlashes]))
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(7))
                guard let self, let pending = self.pendingEnable, pending.id == id else { return }
                self.pendingEnable = nil
                pending.completion(.failure(RobotSetupError("Keine Antwort auf die Motorfreigabe. Bridge-Start, IP und UDP-Port prüfen.")))
            }
        } catch {
            completion(.failure(error))
        }
    }

    private func receiveBridgeReply(on channel: NWConnection) {
        channel.receiveMessage { [weak self] data, _, _, error in
            Task { @MainActor [weak self] in
                guard let self, self.connection === channel else { return }
                if let error {
                    self.onBridgeStatus?("Bridge-Verbindung: " + error.localizedDescription)
                    return
                }
                if let data,
                   let packet = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let response = packet["response"] as? [String: Any]
                    let failed = packet["ok"] as? Bool == false || response?["success"] as? Bool == false
                    let detail = packet["error"] as? String ?? response?["message"] as? String ?? ""
                    if let pending = self.pendingEnable, packet["id"] as? String == pending.id {
                        self.pendingEnable = nil
                        if failed {
                            pending.completion(.failure(RobotSetupError(detail.isEmpty ? "ROS-Service hat die Freigabe abgelehnt." : detail)))
                        } else if packet["ok"] as? Bool == true {
                            pending.completion(.success(()))
                        } else {
                            pending.completion(.failure(RobotSetupError("Unbekannte Antwort auf die Freigabe.")))
                        }
                    } else if failed {
                        self.onBridgeStatus?("ROS-Fehler: " + detail)
                    }
                }
                self.receiveBridgeReply(on: channel)
            }
        }
    }

    func checkConnection(timeout: TimeInterval = 1, completion: @escaping (Bool) -> Void) {
        guard let destination = try? IPv4Address(address: targetHost) else {
            completion(false)
            return
        }

        let request = Request(destination: destination, timeoutInterval: .seconds(timeout))
        connectionPinger.ping(request: request) { result in
            completion((try? result.get()) != nil)
        }
    }


    // MARK: - Publish

    private func send(
        topic: String,
        messageType: String,
        message: [String: ROSValue]
    ) {

        let command =
            ROSPublishCommand(
                topic:
                    topic,

                messageType:
                    messageType,

                message:
                    message
            )


        sendCommand(
            command
        )
    }


    // MARK: - Service Call

    private func call(
        service: String,
        serviceType: String,
        request: [String: ROSValue]
    ) {

        let command =
            ROSServiceCommand(
                service:
                    service,

                serviceType:
                    serviceType,

                request:
                    request
            )


        sendCommand(
            command
        )
    }


    // MARK: - Send UDP Command

    private func sendCommand<
        Command: Encodable
    >(
        _ command: Command
    ) {

        guard RobotProfileStore.shared.selectedProfile != nil else { return }

        guard let encodedCommand =
            try? encoder.encode(
                command
            )

        else {

            print(
                "# EDUARD UDP ERROR | Could not encode command"
            )

            return
        }


        if let json =
            String(
                data:
                    encodedCommand,

                encoding:
                    .utf8
            ) {

            print(
                "# EDUARD UDP SEND | \(json)"
            )
        }


        var packet =
            encodedCommand


        // Python receiver expects every JSON
        // command to end with a newline.
        packet.append(
            0x0A
        )


        connection.send(
            content:
                packet,

            completion:
                .contentProcessed { error in

                    if let error {

                        print(
                            "# EDUARD UDP ERROR | \(error)"
                        )
                    }
                }
        )
    }


    private func sendConfiguredData(_ data: Data) {
        guard RobotProfileStore.shared.selectedProfile != nil else { return }
        connection.send(content: data, completion: .contentProcessed { error in
            if let error { print("ROS bridge send failed: \(error)") }
        })
    }

    // MARK: - Create Connection

    private func makeConnection()
        -> NWConnection {

        let endpointHost =
            NWEndpoint.Host(
                targetHost
            )

        let endpointPort =
            NWEndpoint.Port(
                rawValue:
                    targetPort
            )
            ?? 50505


        return NWConnection(
            host:
                endpointHost,

            port:
                endpointPort,

            using:
                .udp
        )
    }

}
