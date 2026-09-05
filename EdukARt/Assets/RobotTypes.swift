//
//  RobotTypes.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 24.08.26.
//
// Shared Data types

import simd


// MARK: - Robot Control Mode

enum RobotControlMode:
    String,
    CaseIterable,
    Identifiable {

    case real = "Real"
    case simulation = "Simulation"
    case synchronized = "Synchronized"

    var id: String {
        rawValue
    }
}


// MARK: - Robot Drive Mode

enum RobotDriveMode:
    String,
    CaseIterable,
    Identifiable {

    case mechanum = "Mechanum"
    case offroad = "Offroad"

    var id: String {
        rawValue
    }

    // Value expected by Eduard's ROS service.
    var driveKinematicValue: Double {

        switch self {

        case .mechanum:
            return 2.0

        case .offroad:
            return 1.0
        }
    }
}


// MARK: - Robot Pose

struct RobotPose {

    var position:
        SIMD3<Float>

    var rotation:
        Float

    static let zero =
        RobotPose(
            position: .zero,
            rotation: 0
        )
}


// MARK: - Robot Drive Command

struct RobotDriveCommand {

    let forward:
        Double

    let sideways:
        Double

    let rotation:
        Double

    static let stop =
        RobotDriveCommand(
            forward: 0,
            sideways: 0,
            rotation: 0
        )
}
