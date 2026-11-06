import Foundation
import Observation

struct RobotProfile: Codable, Identifiable {
    let id: UUID
    var name: String
}

/// One selection shared by the remote and gameplay. ROS values live in isolated stores.
@MainActor
@Observable
final class RobotProfileStore {
    static let shared = RobotProfileStore()

    private(set) var profiles: [RobotProfile] = []
    private(set) var selectedID: UUID?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storagePrefix: String
    @ObservationIgnored private(set) var selectedSettings: UserDefaults?

    private struct SavedProfiles: Codable {
        var profiles: [RobotProfile]
        var selectedID: UUID?
    }

    init(defaults: UserDefaults = .standard, storagePrefix: String = "robotProfiles") {
        self.defaults = defaults
        self.storagePrefix = storagePrefix
        if let data = defaults.data(forKey: storagePrefix),
           let saved = try? JSONDecoder().decode(SavedProfiles.self, from: data) {
            profiles = saved.profiles
            selectedID = profiles.contains(where: { $0.id == saved.selectedID })
                ? saved.selectedID : profiles.first?.id
        } else {
            let initial = RobotProfile(id: UUID(), name: "Eduard")
            profiles = [initial]
            selectedID = initial.id
            // Migrate the previous global configuration once, including JSON block flags.
            if let store = settings(for: initial.id) {
                for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix("robotROS.") {
                    store.set(value, forKey: key)
                }
            }
        }
        // Seed the additional robot once without changing the existing selection or settings.
        if !defaults.bool(forKey: storagePrefix + ".smlSeeded") {
            let profile = profiles.first(where: { $0.name == "SML_Eduard" })
                ?? RobotProfile(id: UUID(), name: "SML_Eduard")
            if !profiles.contains(where: { $0.id == profile.id }) { profiles.append(profile) }
            if let store = settings(for: profile.id), store.data(forKey: RobotSetupConfiguration.key) == nil {
                try? RobotSetupConfiguration().save(to: store)
            }
            defaults.set(true, forKey: storagePrefix + ".smlSeeded")
        }
        persist()
    }

    var selectedProfile: RobotProfile? {
        profiles.first { $0.id == selectedID }
    }

    func settings(for id: UUID) -> UserDefaults? {
        guard profiles.contains(where: { $0.id == id }) else { return nil }
        return UserDefaults(suiteName: suiteName(for: id))
    }

    @discardableResult
    func add(name: String) -> RobotProfile? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let profile = RobotProfile(id: UUID(), name: name)
        profiles.append(profile)
        if selectedID == nil { selectedID = profile.id }
        persist()
        return profile
    }

    func rename(_ id: UUID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].name = name
        persist()
    }

    // The controller stops outgoing commands before changing or deleting the selection.
    func select(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        selectedID = id
        persist()
    }

    func delete(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        settings(for: id)?.removePersistentDomain(forName: suiteName(for: id))
        profiles.removeAll { $0.id == id }
        if selectedID == id { selectedID = profiles.first?.id }
        persist()
    }

    private func suiteName(for id: UUID) -> String {
        storagePrefix + ".settings." + id.uuidString
    }

    private func persist() {
        selectedSettings = selectedID.flatMap { settings(for: $0) }
        guard let data = try? JSONEncoder().encode(SavedProfiles(profiles: profiles, selectedID: selectedID)) else { return }
        defaults.set(data, forKey: storagePrefix)
    }
}
