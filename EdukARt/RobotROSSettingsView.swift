import SwiftUI

struct RobotROSSettingsView: View {
    let store: UserDefaults
    @AppStorage private var namespace: String

    init(store: UserDefaults) {
        self.store = store
        _namespace = AppStorage(wrappedValue: "eduard/blue3", "robotROS.namespace", store: store)
    }
    @State private var resetID = UUID()

    var body: some View {
        Form {
            Section {
                ROSTextSettingRow(field: .namespace, store: store)
            } footer: {
                Text("Relative topics and services use this namespace. Names beginning with / are absolute.")
            }
            Section("Drive") {
                ROSTextSettingRow(field: .driveTopic, store: store)
                ROSTextSettingRow(field: .driveMessageType, store: store)
            }
            Section("Operating mode") {
                ROSConfigurationEditor(block: .operatingMode, store: store)
                    .id(resetID)
            }
            Section("Lights") {
                ROSTextSettingRow(field: .lightingTopic, store: store)
                ROSTextSettingRow(field: .lightingMessageType, store: store)
                ROSConfigurationEditor(block: .lights, store: store)
                    .id(resetID)
            }
            Section {
                Button("Reset to \(namespace)") {
                    RobotROSSettings.resetKeepingNamespace(in: store)
                    resetID = UUID()
                }
            } footer: {
                Text("Restores the Eduard defaults for the current namespace.")
            }
        }
        .navigationTitle("ROS Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ROSConfigurationEditor: View {
    let block: RobotROSSettings.Block
    let store: UserDefaults
    @State private var draft = ""
    @State private var savedText = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $draft)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 220)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("ROS configuration")
            HStack {
                Text("Set enabled to false if unsupported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Apply") {
                    do {
                        try block.save(draft, in: store)
                        savedText = draft
                        errorMessage = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .disabled(draft == savedText)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear {
            draft = block.text(in: store)
            savedText = draft
        }
    }
}

private struct ROSTextSettingRow: View {
    let field: RobotROSSettings.TextField
    @AppStorage private var value: String

    init(field: RobotROSSettings.TextField, store: UserDefaults) {
        self.field = field
        _value = AppStorage(wrappedValue: field.defaultValue, field.key, store: store)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: field.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(field.title, text: $value)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(Text(verbatim: field.title))
        }
    }
}

