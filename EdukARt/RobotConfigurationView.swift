import SwiftUI

private struct RobotInstallTarget: Identifiable {
    let id: String
    let label: String
    let matches: String
    let installable: Bool
}

struct RobotConfigurationView: View {
    @ObservedObject var controller: RobotController
    @ObservedObject private var store = RobotConfigurationStore.shared
    @State private var draft = RobotConfiguration.defaults
    @State private var password = ""
    @State private var excludedTag = "0"
    @State private var status = ""
    @State private var analysisReport = ""
    @State private var installTargets: [RobotInstallTarget] = []
    @State private var selectedTargetID = ""
    @State private var isBusy = false

    var body: some View {
        Form {
            Section("Verbindung") {
                field("IP-Adresse / Host", $draft.host)
                TextField("SSH-Port", value: $draft.sshPort, format: .number)
                    .keyboardType(.numberPad)
                field("SSH-Benutzer", $draft.sshUsername)
                SecureField("SSH-Passwort", text: $password)
                TextField("Bridge UDP-Port", value: $draft.udpPort, format: .number)
                    .keyboardType(.numberPad)
                TextField("Ausgeschlossene AprilTag-ID (leer = keine)", text: $excludedTag)
                    .keyboardType(.numberPad)
                Text("Das SSH-Passwort wird im Schlüsselbund gespeichert.")
                    .font(.caption)
            }
            Section("Namespace") {
                field("ROS-Namespace", $draft.namespace)
                Text("Relative Namen in den JSON-Paketen verwenden diesen Namespace. Namen mit / bleiben unverändert.")
                    .font(.caption)
            }
            Section("Enable/Disable") {
                jsonEditor("Enable JSON", text: $draft.enableAction, height: 170)
                jsonEditor("Disable JSON", text: $draft.disableAction, height: 170)
                Text("$driveKinematic steht als JSON-String im Editor und wird vor dem Senden zu einer Ganzzahl (1 = Offroad, 2 = Mecanum). Die übrigen Moduswerte können direkt als JSON-Zahlen bearbeitet werden.")
                    .font(.caption)
            }
            Section("Motoren/Fahren") {
                jsonEditor("Fahrpaket JSON", text: $draft.driveMessage, height: 220)
                Text("Vollständiges Bridge-Paket mit kind, topic, messageType und message. $forward, $sideways und $rotation sind JSON-Strings im Editor und werden zu Zahlen. $rotation verwendet die bisherige EdukARt-Drehrichtung.")
                    .font(.caption)
            }
            Section("Lichter") {
                jsonEditor("Lichtpaket JSON", text: $draft.lightsAction, height: 220)
                Text("$lightingName wird zu Text (all, left_side oder right_side). $red, $green, $blue und $mode werden zu Ganzzahlen; $brightness wird zu einer Zahl von 0 bis 1. Platzhalter im Editor als JSON-Strings schreiben.")
                    .font(.caption)
            }
            Section("Installation") {
                Button("ROS-Umgebung analysieren") { runSetup("discover") }
                    .disabled(isBusy || !RobotSSHSetup.isAvailable)
                if !installTargets.isEmpty {
                    Picker("Zielumgebung", selection: $selectedTargetID) {
                        Text("Bitte wählen").tag("")
                        ForEach(installTargets) { target in
                            Text(target.label + " · " + target.matches).tag(target.id)
                        }
                    }
                }
                Button("Install ROS bridge") { runSetup("install") }
                    .disabled(isBusy || selectedTargetID.isEmpty || !RobotSSHSetup.isAvailable)
                if isBusy { ProgressView() }
                if !RobotSSHSetup.isAvailable {
                    Text("SSH-Installation benötigt die Citadel-Paketabhängigkeit im Xcode-Projekt.")
                        .font(.caption)
                }
                if !analysisReport.isEmpty {
                    Text(analysisReport).font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            Section("Einstellungen") {
                Button("Änderungen speichern") { save() }
                Button("Reset to default", role: .destructive) { reset() }
                Text("JSON-Aktionen: kind, topic/messageType/message oder service/serviceType/request. {} deaktiviert eine Aktion. Relative Namen verwenden den Namespace.")
                    .font(.caption)
                Text("Reset setzt nur die lokale Konfiguration zurück und löscht das SSH-Passwort aus dem Schlüsselbund.")
                    .font(.caption)
            }
            if !status.isEmpty {
                Section("Status") { Text(status).textSelection(.enabled) }
            }
            if !draft.report.isEmpty {
                Section("Erkennungsbericht") {
                    Text(draft.report).font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .disabled(isBusy)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .navigationTitle("Aktiver Eduard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private func field(_ title: String, _ value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title).font(.caption)
            TextField(title, text: value, axis: .vertical)
                .accessibilityLabel(Text(verbatim: title))
        }
    }

    private func jsonEditor(_ title: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption)
            TextEditor(text: text)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: height)
                .accessibilityLabel(Text(verbatim: title))
        }
    }

    private func load() {
        draft = store.configuration
        draft.formatJSONFields()
        excludedTag = draft.excludedAprilTagID.map(String.init) ?? ""
        password = store.password
        selectedTargetID = ""
        installTargets = []
    }

    private func save() {
        do {
            try prepareAndSave()
            status = "Einstellungen gespeichert."
        } catch {
            status = error.localizedDescription
        }
    }

    private func prepareAndSave() throws {
        let value = excludedTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            draft.excludedAprilTagID = nil
        } else if let id = Int(value), id >= 0 {
            draft.excludedAprilTagID = id
        } else {
            throw RobotConfigurationError("Eine gültige AprilTag-ID eingeben.")
        }
        draft.formatJSONFields()
        try store.save(draft, password: password)
        controller.eduard.reconnect()
    }

    private func reset() {
        do {
            try store.reset()
            load()
            controller.eduard.reconnect()
            status = "Standardwerte wiederhergestellt."
        } catch {
            status = error.localizedDescription
        }
    }

    private func runSetup(_ action: String) {
        guard !isBusy else { return }
        do {
            try prepareAndSave()
        } catch {
            status = error.localizedDescription
            return
        }
        isBusy = true
        status = action == "discover" ? "ROS-Umgebung wird analysiert …" : "Bridge wird aktualisiert …"
        Task {
            do {
                let result = try await RobotSSHSetup.run(
                    action: action, config: draft, password: password,
                    target: action == "install" ? selectedTargetID : nil
                )
                if action == "discover" {
                    showAnalysis(result)
                } else {
                    status = result["message"] as? String ?? "Bridge installiert."
                    if let health = result["health"] as? [String: Any],
                       let instance = health["instance"] as? String,
                       let port = UInt16(exactly: draft.udpPort) {
                        try await RobotBridgeProbe().check(host: draft.host, port: port, instance: instance)
                        status = "Bridge aktualisiert und vom iPhone über WLAN erreichbar."
                    }
                }
            } catch {
                status = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func showAnalysis(_ result: [String: Any]) {
        let rawTargets = result["candidates"] as? [[String: Any]] ?? []
        installTargets = rawTargets.compactMap { item in
            guard item["installable"] as? Bool == true,
                  let id = item["id"] as? String,
                  let label = item["label"] as? String else { return nil }
            let matches = (item["matches"] as? [String] ?? []).joined(separator: ", ")
            return RobotInstallTarget(id: id, label: label,
                                      matches: matches.isEmpty ? "keine Eduard-Schnittstelle erkannt" : matches,
                                      installable: true)
        }
        selectedTargetID = result["selected"] as? String ?? ""
        let findings = rawTargets.compactMap { item -> String? in
            guard let label = item["label"] as? String else { return nil }
            let matches = (item["matches"] as? [String] ?? []).joined(separator: ", ")
            return label + ": " + (matches.isEmpty ? "keine passende Schnittstelle" : matches)
        }
        let errors = result["errors"] as? [String] ?? []
        analysisReport = (findings + errors).joined(separator: "\n")
        status = result["message"] as? String ?? "ROS-Analyse abgeschlossen."
    }

}
