//
//  RobotTarget.swift
//  EdukARt
//

import Foundation
import simd

protocol RobotTarget: AnyObject {
    var name: String { get }
    var position: SIMD3<Float> { get set }
    var collisionSize: SIMD3<Float> { get }
    var chassisModelName: String { get }
    var frontLeftWheelModelName: String { get }
    var frontRightWheelModelName: String { get }
    var backLeftWheelModelName: String { get }
    var backRightWheelModelName: String { get }
    func move(input: ControlInput, step: Float) -> SIMD3<Float>
}
