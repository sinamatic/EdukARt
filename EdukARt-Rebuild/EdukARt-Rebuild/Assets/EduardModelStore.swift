//
//  EduardModelStore.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 22.08.26.
//

import RealityKit

@MainActor
final class EduardModelStore: ObservableObject {

    @Published private(set) var model: Entity?

    func load() async {
        guard model == nil else {
            return
        }

        PerformanceLogger.shared.start("Preload Eduard")

        do {
            model = try await Entity(named: "eduard")

            PerformanceLogger.shared.end("Preload Eduard")
        } catch {
            print("Could not preload Eduard:", error)
        }
    }
}
