//
//  Obstacle.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import Foundation
import simd

enum ObstacleShape {
    case box
}

struct Obstacle: Identifiable {
    let id = UUID()
    var name: String
    var shape: ObstacleShape
    var position: SIMD3<Float>
    var size: SIMD3<Float>
}
