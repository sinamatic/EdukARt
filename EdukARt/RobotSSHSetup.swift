import Foundation
import Security

#if canImport(Citadel) && canImport(NIOSSH)
import Citadel
import NIOCore
import NIOPosix
import NIOSSH
import Darwin

private final class RobotHostKeyValidator: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    let account: String

    nonisolated init(host: String, port: Int) {
        account = "hostkey.\(host):\(port)"
    }

    nonisolated func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        let key = String(openSSHPublicKey: hostKey)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "EdukARt.RobotSSH",
            kSecAttrAccount as String: account
        ]
        var read = query
        read[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &result)
        if status == errSecSuccess {
            guard let saved = result as? Data, saved == Data(key.utf8) else {
                validationCompletePromise.fail(RobotConfigurationError("SSH-Hostschlüssel hat sich geändert."))
                return
            }
        } else if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data(key.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                validationCompletePromise.fail(RobotConfigurationError("SSH-Hostschlüssel konnte nicht gespeichert werden."))
                return
            }
        } else {
            validationCompletePromise.fail(RobotConfigurationError("SSH-Hostschlüssel konnte nicht gelesen werden."))
            return
        }
        validationCompletePromise.succeed(())
    }
}
#endif

enum RobotSSHSetup {
    static var isAvailable: Bool {
        #if canImport(Citadel) && canImport(NIOSSH)
        true
        #else
        false
        #endif
    }

    static func run(action: String, config: RobotConfiguration, password: String, target: String? = nil) async throws -> [String: Any] {
        #if canImport(Citadel) && canImport(NIOSSH)
        try config.validate()
        guard !password.isEmpty else {
            throw RobotConfigurationError("SSH-Passwort eingeben.")
        }
        guard let bridgeURL = Bundle.main.url(forResource: "edukart_bridge_v2", withExtension: "py"),
              let managerURL = Bundle.main.url(forResource: "edukart_remote_setup", withExtension: "py") else {
            throw RobotConfigurationError("Die Python-Bridge fehlt im App-Bundle.")
        }
        // A fixed identity keeps one managed bridge for the single active robot.
        let identity = "00000000-0000-0000-0000-000000000001"
        let payload: [String: Any] = [
            "action": action,
            "config": [
                "environment": config.environment, "udpPort": String(config.udpPort)
            ],
            "profile": identity,
            "bridge": try Data(contentsOf: bridgeURL).base64EncodedString(),
            "expected": [
                "drive": try descriptor(config.driveMessage, config: config),
                "enable": try descriptor(config.enableAction, config: config),
                "lights": try descriptor(config.lightsAction, config: config)
            ],
            "target": target ?? ""
        ]
        let payload64 = try JSONSerialization.data(withJSONObject: payload).base64EncodedString()
        let manager64 = try Data(contentsOf: managerURL).base64EncodedString()
        let program = "import base64,json; PAYLOAD=json.loads(base64.b64decode('\(payload64)')); exec(base64.b64decode('\(manager64)'))"
        let command = "timeout 180s python3 -c " + quote(program)
        let host = config.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let client = try await SSHClient.connect(
            host: host, port: config.sshPort,
            authenticationMethod: .passwordBased(username: config.sshUsername, password: password),
            hostKeyValidator: .custom(RobotHostKeyValidator(host: host, port: config.sshPort)),
            reconnect: .never, connectTimeout: .seconds(10)
        )
        let deadline = Task {
            try await Task.sleep(for: .seconds(190))
            try? await client.close()
        }
        do {
            let output = try await client.executeCommand(command, maxResponseSize: 2_000_000, mergeStreams: true)
            deadline.cancel()
            try? await client.close()
            let text = String(buffer: output)
            guard let line = text.components(separatedBy: "\n").last(where: { $0.hasPrefix("EDUKART_RESULT=") }),
                  let envelope = try JSONSerialization.jsonObject(with: Data(line.dropFirst("EDUKART_RESULT=".count).utf8)) as? [String: Any] else {
                throw RobotConfigurationError("Keine gültige Antwort vom Roboter. " + String(text.suffix(1000)))
            }
            guard envelope["ok"] as? Bool == true, let result = envelope["result"] as? [String: Any] else {
                throw RobotConfigurationError(envelope["error"] as? String ?? "Fehler auf dem Roboter.")
            }
            return result
        } catch {
            deadline.cancel()
            try? await client.close()
            throw error
        }
        #else
        throw RobotConfigurationError("SSH-Einrichtung benötigt die Citadel/NIOSSH-Paketabhängigkeit im Xcode-Projekt.")
        #endif
    }

    #if canImport(Citadel) && canImport(NIOSSH)
    private static func descriptor(_ text: String, config: RobotConfiguration) throws -> [String: String] {
        let object = try RobotConfiguration.object(text)
        let isService = object["kind"] as? String == "service"
        let key = isService ? "service" : "topic"
        let typeKey = isService ? "serviceType" : "messageType"
        guard let name = object[key] as? String, let type = object[typeKey] as? String else {
            return [:]
        }
        return ["name": config.resolvedName(name), "type": type]
    }

    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    #endif
}
