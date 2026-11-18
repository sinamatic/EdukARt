
import SwiftUI
import Observation

@MainActor
@Observable
final class RobotSetupModel {
    var config = RobotSetupConfiguration()
    var password = ""
    var status = "Verbindungsdaten prüfen und mit „Automatisch ausfüllen“ die ROS-Konfiguration dieses Roboters ermitteln."
    var busy = false
    private var loaded = false

    func load(store: UserDefaults, profile: UUID) {
        guard !loaded else { return }
        config = RobotSetupConfiguration.load(from: store) ?? .init()
        config.formatJSONFields()
        password = RobotSecrets.read("password." + profile.uuidString) ?? "aut0n0hm"
        loaded = true
    }

    func save(store: UserDefaults, profile: UUID) throws {
        config.formatJSONFields()
        try config.save(to: store)
        try RobotSecrets.write(password, account: "password." + profile.uuidString)
    }

    func perform(_ action: String, store: UserDefaults, profile: UUID) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        status = action == "discover" ? "Suche ROS-Schnittstellen im lokalen WLAN …" : "Verbinde mit dem Roboter …"
        do {
            try config.validateConnection()
            if action != "discover" { try config.validate() }
            try RobotSecrets.write(password, account: "password." + profile.uuidString)
            let result = try await RobotSSHSetup.run(action: action, config: config, password: password, profile: profile)
            if action == "discover" {
                try applyDiscovery(result)
                do {
                    try config.save(to: store)
                } catch {
                    status += "\nErkennung abgeschlossen, aber noch nicht gespeichert: " + error.localizedDescription
                }
            } else {
                try config.save(to: store)
                status = result["message"] as? String ?? "Fertig."
                if action == "start",
                   let health = result["health"] as? [String: Any],
                   let instance = health["instance"] as? String,
                   let port = UInt16(config.udpPort) {
                    try await RobotBridgeProbe().check(host: config.host, port: port, instance: instance)
                    status = "Bridge läuft. Verbindung vom iPhone über WLAN bestätigt."
                }
            }
        } catch {
            status = "Fehler: " + error.localizedDescription
        }
    }

    private func applyDiscovery(_ result: [String: Any]) throws {
        config.report = String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
        config.container = result["container"] as? String ?? config.container
        config.setup = result["setup"] as? String ?? config.setup
        if let environment = result["environment"] as? [String: String] {
            config.environment = String(decoding: try JSONSerialization.data(withJSONObject: environment, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
        }
        config.lastDiscovery = Date().formatted(date: .numeric, time: .shortened)
        let topics = result["topics"] as? [[String: Any]] ?? []
        let services = result["services"] as? [[String: Any]] ?? []
        let drives = topics.filter {
            ($0["types"] as? [String])?.contains("geometry_msgs/msg/Twist") == true &&
            ($0["subscribers"] as? Int ?? 0) > 0
        }
        let preferred = drives.filter { ($0["name"] as? String)?.hasSuffix("/cmd_vel") == true }
        let candidates = preferred.isEmpty ? drives : preferred
        var notes: [String] = []
        if candidates.count == 1, let name = candidates.first?["name"] as? String {
            config.driveTopic = name
            config.driveType = "geometry_msgs/msg/Twist"
            config.namespace = name.split(separator: "/").dropLast().joined(separator: "/")
            config.driveMessage = RobotSetupConfiguration().driveMessage
            notes.append("Fahrtopic erkannt.")
        } else {
            notes.append("Fahrtopic nicht eindeutig: vorhandene Werte beibehalten. Bericht prüfen.")
        }
        let enables = services.filter {
            ($0["types"] as? [String])?.contains("std_srvs/srv/SetBool") == true &&
            ($0["name"] as? String) == config.name("enable")
        }
        if enables.count == 1, let name = enables.first?["name"] as? String {
            for enabled in [true, false] {
                let action: [String: Any] = ["kind": "service", "service": name,
                    "serviceType": "std_srvs/srv/SetBool", "request": ["data": enabled]]
                let text = String(decoding: try JSONSerialization.data(withJSONObject: action, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
                if enabled { config.enableAction = text } else { config.disableAction = text }
            }
            notes.append("SetBool-Freigabe vorgeschlagen; Zuordnung vor dem Fahren prüfen.")
        } else {
            notes.append("Freigabe nicht eindeutig: vorhandene JSON-Aktionen beibehalten.")
        }
        notes.append("Licht bleibt manuell konfigurierbar. Es wurden keine Fahr- oder Servicebefehle ausgeführt.")
        status = notes.joined(separator: "\n")
    }
}

struct RobotSetupView: View {
    let store: UserDefaults
    let profile: UUID
    @State private var model = RobotSetupModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            RobotSSHConnectionSection(config: $model.config, password: $model.password)
            RobotSetupActionsSection(model: model, store: store, profile: profile)
            RobotRuntimeSection(config: $model.config)
            RobotDriveSetupSection(config: $model.config)
            RobotActionEditor(title: "Motoren freigeben", text: $model.config.enableAction)
            RobotActionEditor(title: "Motoren sperren", text: $model.config.disableAction)
            RobotActionEditor(title: "Licht ($red, $green, $blue, $brightness, $mode)", text: $model.config.lightsAction)
            Section("Einstellungen") {
                Button("Änderungen speichern") {
                    do {
                        try model.save(store: store, profile: profile)
                        model.status = "Einstellungen gespeichert."
                    } catch {
                        model.status = error.localizedDescription
                    }
                }
                Text("JSON-Aktionen: kind, topic/messageType/message oder service/serviceType/request. {} deaktiviert eine Aktion. Namen mit / sind absolut.")
                    .font(.caption)
            }
            Section("Erkennungsbericht / manuelle Notizen") {
                if !model.config.lastDiscovery.isEmpty {
                    Text("Zuletzt untersucht: \(model.config.lastDiscovery)")
                }
                TextEditor(text: $model.config.report)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 240)
                    .accessibilityLabel("Erkennungsbericht")
            }
        }
        .disabled(model.busy)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .navigationTitle("Roboter einrichten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    do {
                        try model.save(store: store, profile: profile)
                        dismiss()
                    } catch {
                        model.status = error.localizedDescription
                    }
                }
                .disabled(model.busy)
            }
        }
        .interactiveDismissDisabled(model.busy)
        .task { model.load(store: store, profile: profile) }
    }
}

private struct RobotSSHConnectionSection: View {
    @Binding var config: RobotSetupConfiguration
    @Binding var password: String

    var body: some View {
        Section {
            RobotSetupField(title: "IP-Adresse / Host", text: $config.host)
            RobotSetupField(title: "SSH-Port", text: $config.sshPort)
            RobotSetupField(title: "SSH-Benutzer", text: $config.username)
            VStack(alignment: .leading) {
                Text("SSH-Passwort").font(.caption)
                TextField("SSH-Passwort", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            RobotSetupField(title: "Bridge UDP-Port", text: $config.udpPort)
        } header: {
            Text("Verbindung")
        } footer: {
            Text("iPhone mit dem Roboter-WLAN verbinden. Erkennung, Installation und Start funktionieren ohne Internet. Das Passwort wird im Schlüsselbund gespeichert.")
        }
    }
}

private struct RobotSetupActionsSection: View {
    @Bindable var model: RobotSetupModel
    let store: UserDefaults
    let profile: UUID

    var body: some View {
        Section("Einrichtung per SSH") {
            Button("Automatisch ausfüllen") {
                Task { await model.perform("discover", store: store, profile: profile) }
            }
            Button("install ROSbridge on Robot") {
                Task { await model.perform("install", store: store, profile: profile) }
            }
            Button("start rosbridge") {
                Task { await model.perform("start", store: store, profile: profile) }
            }
            if model.busy { ProgressView("Bitte warten …") }
            Text(model.status)
                .font(.callout)
                .textSelection(.enabled)
            Text("Automatisch ausfüllen ersetzt eindeutig erkannte ROS-Felder. Die Angaben bleiben editierbar. Unbekannte Felder bleiben erhalten und stehen im Bericht.")
                .font(.caption)
        }
    }
}

private struct RobotRuntimeSection: View {
    @Binding var config: RobotSetupConfiguration

    var body: some View {
        Section {
            RobotSetupField(title: "ROS-Container (leer = direkt auf dem Host)", text: $config.container)
            RobotSetupField(title: "ROS-Setup-Befehl", text: $config.setup)
            Text("ROS-Umgebung als JSON, z. B. {\"ROS_DOMAIN_ID\":\"0\"}")
                .font(.caption)
            TextEditor(text: $config.environment)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 80)
                .accessibilityLabel("ROS-Umgebung JSON")
        } header: {
            Text("ROS-Laufzeit")
        } footer: {
            Text("Das Setup wird als Shell-Befehl ausgeführt. Die Bridge läuft im gewählten Container und endet bei dessen Neustart. Danach erneut „start rosbridge“ drücken. Es werden keine Pakete heruntergeladen.")
        }
    }
}

private struct RobotDriveSetupSection: View {
    @Binding var config: RobotSetupConfiguration

    var body: some View {
        Section("Fahren") {
            RobotSetupField(title: "Namespace", text: $config.namespace)
            RobotSetupField(title: "Topic", text: $config.driveTopic)
            RobotSetupField(title: "Message type", text: $config.driveType)
            TextEditor(text: $config.driveMessage)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 160)
                .accessibilityLabel("Fahrnachricht JSON")
            Text("Variablen als JSON-Strings: $forward, $sideways, $rotation. $rotation enthält die bisherige EdukARt-Drehrichtung.")
                .font(.caption)
        }
    }
}

private struct RobotActionEditor: View {
    let title: String
    @Binding var text: String

    var body: some View {
        Section {
            TextEditor(text: $text)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 150)
                .accessibilityLabel(Text(verbatim: title))
        } header: {
            Text(verbatim: title)
        }
    }
}

private struct RobotSetupField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title).font(.caption)
            TextField(title, text: $text, axis: .vertical)
                .accessibilityLabel(Text(verbatim: title))
        }
    }
}
