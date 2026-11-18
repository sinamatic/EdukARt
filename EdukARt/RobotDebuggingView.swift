
import SwiftUI

/// Lives beside the remote controls, so recording does not cover or disable the joysticks.
struct RobotDebuggingView: View {
    @ObservedObject var controller: RobotController
    let store: UserDefaults
    let profile: UUID
    @State private var expanded = false
    @State private var recording = false
    @State private var summary = ""
    @State private var report = ""
    @State private var stateEvents: [[String: String]] = []

    var body: some View {
        DisclosureGroup("Debugging", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                Text(controller.isEnabled ? "App-Motorfreigabe: aktiv" : "App-Motorfreigabe: aus – keine Fahrbefehle an den Roboter")
                    .foregroundStyle(controller.isEnabled ? Color.green : Color.orange)
                if !controller.isEnabled {
                    Text("Nach dem Öffnen der ROS Settings muss erneut Enable gedrückt werden.")
                        .font(.caption)
                }
                Text("Während der Aufzeichnung unten die Joysticks vorwärts und drehend bewegen. Die Diagnose liest nur ROS-Nachrichten und stoppt keinen Container.")
                    .font(.caption)
                Button("Gespeicherte Einstellungen auslesen") {
                    do {
                        guard let config = RobotSetupConfiguration.load(from: store) else {
                            throw RobotSetupError("Keine ROS-Konfiguration gespeichert.")
                        }
                        let snapshot = try configurationSnapshot(config)
                        report = String(decoding: try JSONSerialization.data(withJSONObject: snapshot,
                            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
                        summary = "Gespeicherte App-Einstellungen ausgelesen. Keine Verbindung zum Roboter erforderlich. SSH-Passwort ist nicht enthalten."
                    } catch {
                        summary = error.localizedDescription
                    }
                }
                .buttonStyle(.bordered)
                .disabled(recording)
                Button("12 Sekunden ROS aufzeichnen") {
                    Task { await record() }
                }
                .buttonStyle(.bordered)
                .disabled(recording)
                if recording {
                    ProgressView("Verbinde / zeichne auf – Joystick jetzt bewegen …")
                }
                if !summary.isEmpty {
                    Text(summary).font(.callout).textSelection(.enabled)
                }
                if !report.isEmpty {
                    ShareLink("Debugbericht teilen", item: report)
                    DisclosureGroup("Vollständiger Bericht") {
                        Text(report)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .onChange(of: controller.isEnabled) { _, _ in
            if recording { stateEvents.append(controller.driveDebugState) }
        }
        .onChange(of: controller.controlMode) { _, _ in
            if recording { stateEvents.append(controller.driveDebugState) }
        }
    }

    private func configurationSnapshot(_ config: RobotSetupConfiguration) throws -> [String: Any] {
        var values = try JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any] ?? [:]
        // Arbitrary environment variables and free-form reports may contain credentials.
        values.removeValue(forKey: "environment")
        values.removeValue(forKey: "report")
        values["environmentVariableNames"] = (try? RobotSetupConfiguration.object(config.environment).keys.sorted()) ?? []
        values["resolvedDriveTopic"] = config.name(config.driveTopic)
        values["enablePacket"] = try config.actionData(config.enableAction).map {
            try JSONSerialization.jsonObject(with: $0)
        }
        let robot = RobotProfileStore.shared.profiles.first { $0.id == profile }
        return ["robot": robot?.name ?? profile.uuidString,
                "aprilTagNumber": robot?.aprilTagNumber as Any? ?? NSNull(),
                "configuration": values,
                "appState": controller.driveDebugState]
    }

    @MainActor
    private func record() async {
        guard !recording else { return }
        recording = true
        defer { recording = false }
        summary = ""
        let initialState = controller.driveDebugState
        stateEvents = [initialState]
        do {
            guard let config = RobotSetupConfiguration.load(from: store) else {
                throw RobotSetupError("Keine ROS-Konfiguration gespeichert.")
            }
            let password = RobotSecrets.read("password." + profile.uuidString) ?? "aut0n0hm"
            report = ""
            let snapshot = try configurationSnapshot(config)
            var result = try await RobotSSHSetup.run(action: "debug", config: config, password: password, profile: profile)
            result["savedSettings"] = snapshot
            result["appStateAtStart"] = initialState
            result["appStateAtEnd"] = controller.driveDebugState
            result["appStateChanges"] = stateEvents
            report = String(decoding: try JSONSerialization.data(withJSONObject: result,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
            let drive = result["drive"] as? [String: Any] ?? [:]
            let joy = result["joy"] as? [String: Any] ?? [:]
            let count = drive["count"] as? Int ?? 0
            let nonzero = drive["nonzeroCount"] as? Int ?? 0
            let joyCount = joy["count"] as? Int ?? 0
            if let error = drive["error"] as? String {
                summary = "Fahrtopic konnte nicht gelesen werden: " + error
            } else if count == 0 {
                if !controller.isEnabled && stateEvents.allSatisfy({ $0["enabled"] == "false" }) {
                    summary = "Keine Fahrnachrichten: Die App war während der Aufzeichnung nicht freigegeben. Enable drücken, Bestätigung abwarten und erneut aufzeichnen."
                } else {
                    summary = "Keine Fahrnachrichten empfangen. App-Steuermodus, Fahrtopic, Message-Typ und Bridge prüfen."
                }
            } else if nonzero == 0 {
                summary = "\(count) Fahrnachrichten empfangen, aber nur Nullwerte. Joystick-Eingabe und Fahrvorlage prüfen."
            } else {
                summary = "\(count) Fahrnachrichten, davon \(nonzero) mit Bewegung. Fahrwerte erreichen ROS. Notaus, tatsächliche Motorfreigabe, Treiber-Empfänger/QoS und Motorversorgung prüfen. Eine erfolgreiche Enable-Antwort bestätigt allein noch keine Motorfreigabe."
            }
            summary += "\nJoystick-Topic: \(joyCount) Nachrichten. "
            summary += joyCount > 0
                ? "Eine Beeinflussung durch den Joystick-Treiber ist möglich, damit aber noch nicht bewiesen."
                : "Im Messzeitraum wurden keine Joystick-Nachrichten empfangen."
        } catch {
            summary = "Debugging fehlgeschlagen: " + error.localizedDescription
        }
    }
}
