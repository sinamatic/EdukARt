
import Foundation
import Network

/// Checks the actual iPhone-to-robot UDP path after the SSH-side startup check.
@MainActor
final class RobotBridgeProbe {
    private var continuation: CheckedContinuation<Void, Error>?
    private var connection: NWConnection?
    private var deadline: Task<Void, Never>?
    private let requestID = UUID().uuidString

    func check(host: String, port: UInt16, instance: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
                finish(RobotSetupError("Ungültiger UDP-Port."))
                return
            }
            let connection = NWConnection(host: .init(host), port: endpointPort, using: .udp)
            self.connection = connection
            connection.stateUpdateHandler = { state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self.send(instance: instance)
                    case .failed(let error):
                        self.finish(error)
                    default:
                        break
                    }
                }
            }
            deadline = Task {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                self.finish(RobotSetupError("Bridge läuft auf dem Roboter, antwortet aber nicht über WLAN. UDP-Port und Netzwerkzugriff prüfen."))
            }
            connection.start(queue: .global(qos: .userInitiated))
        }
    }

    private func send(instance: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: ["kind": "health", "id": requestID]) else { return }
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error { Task { @MainActor in self.finish(error) } }
        })
        connection?.receiveMessage { data, _, _, error in
            Task { @MainActor in
                if let error { self.finish(error); return }
                guard let data,
                      let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      response["id"] as? String == self.requestID,
                      response["instance"] as? String == instance,
                      response["version"] as? Int == 2 else {
                    self.finish(RobotSetupError("Unerwartete Antwort am Bridge-Port."))
                    return
                }
                self.finish(nil)
            }
        }
    }

    private func finish(_ error: Error?) {
        guard let continuation else { return }
        self.continuation = nil
        deadline?.cancel()
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        if let error { continuation.resume(throwing: error) }
        else { continuation.resume() }
    }
}
