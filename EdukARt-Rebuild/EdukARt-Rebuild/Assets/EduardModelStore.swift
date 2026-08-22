//
//  EduardModelStore.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 22.08.26.
//
import RealityKit
import Combine

@MainActor
final class EduardModelStore: ObservableObject {

    @Published private(set) var model: Entity?

    func load() async {

        // Nicht nochmal laden, wenn es schon da ist
        guard model == nil else {
            return
        }

        PerformanceLogger.shared.start(
            "Preload Eduard"
        )

        do {
            model = try await Entity(
                named: "eduard-mecanum"
            )

            print(
                "✅ Preload finished, model exists:",
                model != nil
            )

        } catch {
            print(
                "❌ Could not preload Eduard:",
                error
            )
        }

        PerformanceLogger.shared.end(
            "Preload Eduard"
        )
    }
}
