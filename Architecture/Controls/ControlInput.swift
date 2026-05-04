//
//  ControlInput.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import Foundation
import simd

protocol ControlSource: AnyObject {
    func readInput() -> ControlInput
}

struct ControlInput: Equatable {
    let direction: SIMD2<Float>

    static let idle = ControlInput(direction: .zero)

    var speed: Float {
        simd_length(direction)
    }

    var isForwardPressed: Bool {
        direction.y < -0.5
    }

    var isBackwardPressed: Bool {
        direction.y > 0.5
    }

    var isLeftPressed: Bool {
        direction.x < -0.5
    }

    var isRightPressed: Bool {
        direction.x > 0.5
    }
}

final class JoystickController: ControlSource {
    private var currentInput: ControlInput = .idle

    func updateInput(_ input: ControlInput) {
        currentInput = input
    }

    func readInput() -> ControlInput {
        currentInput
    }
}

final class PS4Controller: ControlSource {
    func readInput() -> ControlInput {
        .idle
    }
}

final class OSCController: ControlSource {
    func readInput() -> ControlInput {
        .idle
    }
}
