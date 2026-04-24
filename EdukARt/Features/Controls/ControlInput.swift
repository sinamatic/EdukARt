//
//  ControlInput.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import Foundation
import simd

struct ControlInput {
    let direction: SIMD2<Float>

    static let idle = ControlInput(direction: .zero)

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
