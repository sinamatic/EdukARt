//
//  JoystickController.swift
//  EdukARt
//

import Foundation

final class JoystickController: ControlSource {
    private var currentInput: ControlInput = .idle

    func updateInput(_ input: ControlInput) {
        currentInput = input
    }

    func readInput() -> ControlInput {
        currentInput
    }
}
