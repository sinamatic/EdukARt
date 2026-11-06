
import Foundation
import Security
import Citadel
import NIOCore
import NIOPosix
import Darwin
import NIOSSH

enum RobotSecrets {
    nonisolated static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "EdukARt.RobotSSH",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess,
              let data = value as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    nonisolated static func write(_ value: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "EdukARt.RobotSSH",
            kSecAttrAccount as String: account
        ]
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added = SecItemAdd(insert as CFDictionary, nil)
            guard added == errSecSuccess else { throw SecretError(status: added) }
        } else if status != errSecSuccess {
            throw SecretError(status: status)
        }
    }

    struct SecretError: Error { let status: OSStatus }
}

/// Trust on first use, pinned by host and port. Never silently accepts a changed key.
private final class RobotHostKeyValidator: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    let account: String
    nonisolated init(host: String, port: Int) { account = "hostkey.\(host):\(port)" }

    nonisolated func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        let key = String(openSSHPublicKey: hostKey)
        do {
            if let saved = RobotSecrets.read(account) {
                guard saved == key else {
                    validationCompletePromise.fail(HostKeyChanged())
                    return
                }
            } else {
                try RobotSecrets.write(key, account: account)
            }
            validationCompletePromise.succeed(())
        } catch {
            validationCompletePromise.fail(error)
        }
    }

    struct HostKeyChanged: LocalizedError {
        var errorDescription: String? { "SSH-Hostschlüssel hat sich geändert. Verbindung abgebrochen." }
    }
}

enum RobotSSHSetup {
    static func run(action: String, config: RobotSetupConfiguration, password: String, profile: UUID) async throws -> [String: Any] {
        try config.validateConnection()
        guard let port = Int(config.sshPort),
              let bridgeURL = Bundle.main.url(forResource: "edukart_bridge_v2", withExtension: "py"),
              let managerURL = Bundle.main.url(forResource: "edukart_remote_setup", withExtension: "py") else {
            throw RobotSetupError("Die mitgelieferten Python-Skripte fehlen im App-Bundle.")
        }
        var payload: [String: Any] = [
            "action": action,
            "config": ["container": config.container, "setup": config.setup,
                       "environment": config.environment, "udpPort": config.udpPort],
            "profile": profile.uuidString,
            "bridge": try Data(contentsOf: bridgeURL).base64EncodedString()
        ]
        if action == "debug" {
            guard let url = Bundle.main.url(forResource: "edukart_ros_debug", withExtension: "py") else {
                throw RobotSetupError("Debugging-Skript fehlt im App-Bundle.")
            }
            payload["debugScript"] = try Data(contentsOf: url).base64EncodedString()
            payload["debugConfig"] = ["namespace": config.namespace,
                "driveTopic": config.name(config.driveTopic), "driveType": config.driveType]
        }
        let payload64 = try JSONSerialization.data(withJSONObject: payload).base64EncodedString()
        let manager64 = try Data(contentsOf: managerURL).base64EncodedString()
        let program = "import base64,json; PAYLOAD=json.loads(base64.b64decode('\(payload64)')); exec(base64.b64decode('\(manager64)'))"
        let command = "timeout 180s python3 -c " + quote(program)
        let host = config.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let client: SSHClient
        do {
            client = try await SSHClient.connect(
                host: host, port: port,
                authenticationMethod: .passwordBased(username: config.username, password: password),
                hostKeyValidator: .custom(RobotHostKeyValidator(host: host, port: port)),
                reconnect: .never, connectTimeout: .seconds(10)
            )
        } catch let error as NIOConnectionError {
            throw connectionError(error)
        } catch let error as SSHClientError {
            let detail: String
            switch error {
            case .allAuthenticationOptionsFailed:
                detail = "Der SSH-Server hat die Anmeldung mit Benutzer und Passwort nicht akzeptiert. Benutzername und Passwort prüfen; auch zusätzliche Anmeldeanforderungen des Servers sind möglich."
            case .unsupportedPasswordAuthentication:
                detail = "Der SSH-Server bietet keine direkte Passwortanmeldung an. Die App verwendet derzeit Passwortauthentifizierung; eine Anmeldung per SSH-Schlüssel oder Keyboard-Interactive ist damit nicht gleichzusetzen."
            default:
                detail = "SSH-Anmeldung oder Sitzung konnte nicht eingerichtet werden."
            }
            throw RobotSetupError("""
            SSH-Server \(host):\(port) erreicht.
            \(detail)
            Benutzer: \(config.username)
            Docker und ROS wurden noch nicht untersucht.
            Technische Details: \(String(describing: error))
            """)
        }
        // Closing the channel also unblocks an operation if the remote network disappears.
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
                throw RobotSetupError("Keine gültige Antwort vom Roboter. " + String(text.suffix(2000)))
            }
            guard envelope["ok"] as? Bool == true, let result = envelope["result"] as? [String: Any] else {
                throw RobotSetupError(envelope["error"] as? String ?? "Unbekannter Fehler auf dem Roboter.")
            }
            return result
        } catch {
            deadline.cancel()
            try? await client.close()
            throw error
        }
    }

    private static func connectionError(_ error: NIOConnectionError) -> RobotSetupError {
        let codes = error.connectionErrors.compactMap { ($0.error as? IOError)?.errnoCode }
        let hint: String
        if codes.contains(EACCES) || codes.contains(EPERM) {
            hint = "Netzwerkzugriff verweigert. Auf dem iPhone unter Einstellungen → Datenschutz & Sicherheit → Lokales Netzwerk den Zugriff für EdukARt erlauben."
        } else if codes.contains(EHOSTUNREACH) || codes.contains(ENETUNREACH) {
            hint = "Roboter im Netzwerk nicht erreichbar. iPhone mit dem Roboter-WLAN verbinden, IP prüfen und den lokalen Netzwerkzugriff für EdukARt kontrollieren."
        } else if codes.contains(ECONNREFUSED) {
            hint = "Der SSH-Port lehnt die Verbindung ab. SSH-Port und laufenden SSH-Dienst auf dem Roboter prüfen."
        } else {
            hint = "Roboter-WLAN, IP-Adresse, SSH-Port und lokalen Netzwerkzugriff für EdukARt prüfen. Ein VPN oder eine WLAN-Clientsperre kann die Verbindung verhindern."
        }
        return RobotSetupError("""
        SSH-Verbindung zu \(error.host):\(error.port) konnte nicht aufgebaut werden.
        \(hint)
        Docker wurde noch nicht erreicht; das Passwort wurde noch nicht geprüft.

        Technische Details:
        \(String(describing: error))
        """)
    }

    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
