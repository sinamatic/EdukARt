//
//  PerformanceLogger.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 22.08.26.
//

import Foundation

final class PerformanceLogger {

    static let shared = PerformanceLogger()

    private var times: [String: CFAbsoluteTime] = [:]

    private init() {
    }

    func start(_ name: String) {
        times[name] = CFAbsoluteTimeGetCurrent()
        print("⏱ START:", name)
    }

    func end(_ name: String) {
        guard let startTime = times[name] else {
            return
        }

        let duration =
            CFAbsoluteTimeGetCurrent() - startTime

        print(
            "⏱ END:",
            name,
            String(
                format: "%.3f seconds",
                duration
            )
        )

        times[name] = nil
    }
}
