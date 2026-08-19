//
//  UIARSimulatedRobot.swift
//  EdukARt
//

import RealityKit
import simd

struct UIARSimulatedRobot {
    
    static func draw(
        robot: EduardRobotSimulation,
        referenceWorldTransform: simd_float4x4,
        in arView: ARView
    ) {
        
        // Nicht doppelt erzeugen
        guard arView.scene.findEntity(
            named: "SimulatedEduard"
        ) == nil else {
            return
        }
        
        
        // Gleicher Ursprung wie Map und Track:
        // Reference Tag = (0, 0, 0)
        
        let anchor = AnchorEntity(
            world: referenceWorldTransform
        )
        
        anchor.name = "SimulatedRobotAnchor"
        
        
        let robotEntity = Entity()
        
        robotEntity.name = "SimulatedEduard"
        
        
        // MARK: - Chassis
        
        if let chassis = try? Entity.load(
            named: robot.chassisModelName
        ) {
            
            chassis.name = "EduardChassis"
            
            robotEntity.addChild(
                chassis
            )
        }
        
        
        // MARK: - Front Left
        
        if let wheel = try? Entity.load(
            named: robot.frontLeftWheelModelName
        ) {
            
            wheel.name = "FrontLeftWheel"
            
            robotEntity.addChild(
                wheel
            )
        }
        
        
        // MARK: - Front Right
        
        if let wheel = try? Entity.load(
            named: robot.frontRightWheelModelName
        ) {
            
            wheel.name = "FrontRightWheel"
            
            robotEntity.addChild(
                wheel
            )
        }
        
        
        // MARK: - Back Left
        
        if let wheel = try? Entity.load(
            named: robot.backLeftWheelModelName
        ) {
            
            wheel.name = "BackLeftWheel"
            
            robotEntity.addChild(
                wheel
            )
        }
        
        
        // MARK: - Back Right
        
        if let wheel = try? Entity.load(
            named: robot.backRightWheelModelName
        ) {
            
            wheel.name = "BackRightWheel"
            
            robotEntity.addChild(
                wheel
            )
        }
        
        
        // MARK: - Position
        
        robotEntity.position = SIMD3<Float>(
            robot.position.x,
            robot.position.y,
            robot.position.z
        )
        
        
        // MARK: - Orientation

        let standUpRotation = simd_quatf(
            angle: -.pi / 2,
            axis: SIMD3<Float>(1, 0, 0)
        )

        let directionRotation = simd_quatf(
            angle: .pi,
            axis: SIMD3<Float>(0, 0, 1)
        )

        robotEntity.orientation =
            directionRotation * standUpRotation
        
        
       
        
        
        anchor.addChild(
            robotEntity
        )
        
        arView.scene.addAnchor(
            anchor
        )
    }
    
    static func update(
        simulatedRobot: SimulatedRobotController,
        in arView: ARView
    ) {
        
        guard let entity =
            arView.scene.findEntity(
                named: "SimulatedEduard"
            ) else {
            return
        }
        
        
        entity.position = SIMD3<Float>(
            simulatedRobot.position.x,
            simulatedRobot.position.y,
            simulatedRobot.position.z - 0.14
        )
        
        
        let standUpRotation = simd_quatf(
            angle: -.pi / 2,
            axis: SIMD3<Float>(1, 0, 0)
        )
        
        
        let driveRotation = simd_quatf(
            angle: simulatedRobot.rotation,
            axis: SIMD3<Float>(0, 0, 1)
        )
        
        let directionRotation = simd_quatf(
            angle: .pi,
            axis: SIMD3<Float>(0, 0, 1)
        )
        
        
        entity.orientation =
            driveRotation *
            directionRotation *
            standUpRotation
    }
    
    
    static func remove(
        from arView: ARView
    ) {
        
        guard let entity =
            arView.scene.findEntity(
                named: "SimulatedEduard"
            ) else {
            return
        }
        
        entity.removeFromParent()
    }
}
