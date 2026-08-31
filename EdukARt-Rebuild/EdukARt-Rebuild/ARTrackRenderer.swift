//
//  ARTrackRenderer.swift
//  EdukARt-Rebuild
//
//  Renders the stored 2D race track in RealityKit.
//
//  The track consists of:
//  - a semi-transparent 60 cm wide road surface,
//  - a white dashed center line,
//  - red/white alternating boundary lines
//    30 cm to the left and right of the center line.
//
//  All elements are generated as flat custom meshes.
//  Consecutive sections share vertices at corners,
//  preventing overlapping geometry and Z-fighting.
//

import RealityKit
import simd
import UIKit


final class ARTrackRenderer {

    // MARK: - Road Settings

    /// Complete road width.
    private let roadWidth: Float = 0.60

    /// Distance from center line to each road boundary.
    private let roadHalfWidth: Float = 0.30

    /// Transparency of the black road surface.
    private let roadOpacity: Float = 0.10


    // MARK: - Center Line Settings

    private let centerLineWidth: Float = 0.035

    private let centerDashLength: Float = 0.30

    private let centerGapLength: Float = 0.10


    // MARK: - Boundary Settings

    /// Width of the red/white boundary lines.
    private let boundaryLineWidth: Float = 0.05

    /// Length of one red or white section.
    private let boundarySegmentLength: Float = 0.30


    // MARK: - Height Settings

    /// Base height above the mapped floor.
    private let floorOffset: Float = 0.006

    /// Lines sit slightly above the road surface
    /// to prevent Z-fighting.
    private let lineOffset: Float = 0.001


    // MARK: - Render Track

    func render(
        trackPoints: [StoredTrackPoint],
        parent: Entity
    ) {

        guard trackPoints.count >= 2 else {
            return
        }


        // Remove previously rendered track.
        parent.findEntity(
            named: "ARTrack"
        )?
        .removeFromParent()


        let trackRoot =
            Entity()

        trackRoot.name =
            "ARTrack"

        parent.addChild(
            trackRoot
        )


        // Convert stored 2D map points
        // into local 3D map coordinates.
        let path: [SIMD3<Float>] =
            trackPoints.map {

                SIMD3<Float>(
                    $0.x,
                    floorOffset,
                    $0.z
                )
            }


        let cumulativeDistances =
            calculateCumulativeDistances(
                for: path
            )


        guard let totalLength =
            cumulativeDistances.last,
              totalLength > 0.001
        else {
            return
        }


        // 1. Road surface

        renderRoad(
            path: path,
            parent: trackRoot
        )


        // 2. White dashed center line

        renderCenterLine(
            path: path,
            cumulativeDistances:
                cumulativeDistances,
            totalLength:
                totalLength,
            parent:
                trackRoot
        )


        // 3. Left and right red/white boundaries

        renderBoundaries(
            path: path,
            parent: trackRoot
        )
    }


    // MARK: - Road

    private func renderRoad(
        path: [SIMD3<Float>],
        parent: Entity
    ) {

        guard let mesh =
            createRibbonMesh(
                points: path,
                width: roadWidth
            )
        else {
            return
        }


        let material =
            UnlitMaterial(
                color: .black
            )


        let entity =
            ModelEntity(
                mesh: mesh,
                materials: [
                    material
                ]
            )


        entity.name =
            "ARRoadSurface"


        // Make the black road
        // only slightly visible.
        entity.components.set(
            OpacityComponent(
                opacity:
                    roadOpacity
            )
        )


        parent.addChild(
            entity
        )
    }


    // MARK: - Center Line

    private func renderCenterLine(
        path: [SIMD3<Float>],
        cumulativeDistances: [Float],
        totalLength: Float,
        parent: Entity
    ) {

        let linePath =
            path.map {

                SIMD3<Float>(
                    $0.x,
                    $0.y + lineOffset,
                    $0.z
                )
            }


        guard let mesh =
            createDashedMesh(
                path:
                    linePath,
                cumulativeDistances:
                    cumulativeDistances,
                totalLength:
                    totalLength,
                dashLength:
                    centerDashLength,
                gapLength:
                    centerGapLength,
                width:
                    centerLineWidth
            )
        else {
            return
        }


        let material =
            UnlitMaterial(
                color: .white
            )


        let entity =
            ModelEntity(
                mesh: mesh,
                materials: [
                    material
                ]
            )


        entity.name =
            "ARCenterLine"


        parent.addChild(
            entity
        )
    }


    // MARK: - Boundaries

    private func renderBoundaries(
        path: [SIMD3<Float>],
        parent: Entity
    ) {

        // Generate paths exactly 30 cm
        // left and right of the center line.
        let leftPath =
            offsetPath(
                path,
                lateralOffset:
                    roadHalfWidth,
                verticalOffset:
                    lineOffset
            )


        let rightPath =
            offsetPath(
                path,
                lateralOffset:
                    -roadHalfWidth,
                verticalOffset:
                    lineOffset
            )


        renderBoundary(
            path:
                leftPath,
            name:
                "ARLeftBoundary",
            parent:
                parent
        )


        renderBoundary(
            path:
                rightPath,
            name:
                "ARRightBoundary",
            parent:
                parent
        )
    }


    // MARK: - Boundary

    private func renderBoundary(
        path: [SIMD3<Float>],
        name: String,
        parent: Entity
    ) {

        let cumulativeDistances =
            calculateCumulativeDistances(
                for: path
            )


        guard let totalLength =
            cumulativeDistances.last,
              totalLength > 0.001
        else {
            return
        }


        // RED sections:
        //
        // 0.00 - 0.30
        // 0.60 - 0.90
        // 1.20 - 1.50
        // ...

        if let redMesh =
            createAlternatingMesh(
                path:
                    path,
                cumulativeDistances:
                    cumulativeDistances,
                totalLength:
                    totalLength,
                startOffset:
                    0,
                width:
                    boundaryLineWidth
            )
        {

            let redMaterial =
                UnlitMaterial(
                    color: .red
                )


            let redEntity =
                ModelEntity(
                    mesh:
                        redMesh,
                    materials: [
                        redMaterial
                    ]
                )


            redEntity.name =
                "\(name)Red"


            parent.addChild(
                redEntity
            )
        }


        // WHITE sections:
        //
        // 0.30 - 0.60
        // 0.90 - 1.20
        // 1.50 - 1.80
        // ...

        if let whiteMesh =
            createAlternatingMesh(
                path:
                    path,
                cumulativeDistances:
                    cumulativeDistances,
                totalLength:
                    totalLength,
                startOffset:
                    boundarySegmentLength,
                width:
                    boundaryLineWidth
            )
        {

            let whiteMaterial =
                UnlitMaterial(
                    color: .white
                )


            let whiteEntity =
                ModelEntity(
                    mesh:
                        whiteMesh,
                    materials: [
                        whiteMaterial
                    ]
                )


            whiteEntity.name =
                "\(name)White"


            parent.addChild(
                whiteEntity
            )
        }
    }


    // MARK: - Create Alternating Mesh

    /// Creates every second 30 cm boundary section.
    ///
    /// Called once for red sections
    /// and once for white sections.
    private func createAlternatingMesh(
        path: [SIMD3<Float>],
        cumulativeDistances: [Float],
        totalLength: Float,
        startOffset: Float,
        width: Float
    ) -> MeshResource? {

        var vertices:
            [SIMD3<Float>] = []

        var normals:
            [SIMD3<Float>] = []

        var indices:
            [UInt32] = []


        let completePatternLength =
            boundarySegmentLength
            * 2


        var segmentStart =
            startOffset


        while segmentStart
                < totalLength {

            let segmentEnd =
                min(
                    segmentStart
                    + boundarySegmentLength,
                    totalLength
                )


            let segmentPoints =
                points(
                    fromDistance:
                        segmentStart,
                    toDistance:
                        segmentEnd,
                    path:
                        path,
                    cumulativeDistances:
                        cumulativeDistances
                )


            addRibbon(
                points:
                    segmentPoints,
                width:
                    width,
                vertices:
                    &vertices,
                normals:
                    &normals,
                indices:
                    &indices
            )


            segmentStart +=
                completePatternLength
        }


        return createMeshResource(
            vertices:
                vertices,
            normals:
                normals,
            indices:
                indices,
            name:
                "ARBoundaryMesh"
        )
    }


    // MARK: - Create Dashed Mesh

    private func createDashedMesh(
        path: [SIMD3<Float>],
        cumulativeDistances: [Float],
        totalLength: Float,
        dashLength: Float,
        gapLength: Float,
        width: Float
    ) -> MeshResource? {

        var vertices:
            [SIMD3<Float>] = []

        var normals:
            [SIMD3<Float>] = []

        var indices:
            [UInt32] = []


        let patternLength =
            dashLength
            + gapLength


        var dashStart:
            Float = 0


        while dashStart
                < totalLength {

            let dashEnd =
                min(
                    dashStart
                    + dashLength,
                    totalLength
                )


            let dashPoints =
                points(
                    fromDistance:
                        dashStart,
                    toDistance:
                        dashEnd,
                    path:
                        path,
                    cumulativeDistances:
                        cumulativeDistances
                )


            addRibbon(
                points:
                    dashPoints,
                width:
                    width,
                vertices:
                    &vertices,
                normals:
                    &normals,
                indices:
                    &indices
            )


            dashStart +=
                patternLength
        }


        return createMeshResource(
            vertices:
                vertices,
            normals:
                normals,
            indices:
                indices,
            name:
                "ARCenterLineMesh"
        )
    }


    // MARK: - Solid Ribbon Mesh

    private func createRibbonMesh(
        points: [SIMD3<Float>],
        width: Float
    ) -> MeshResource? {

        var vertices:
            [SIMD3<Float>] = []

        var normals:
            [SIMD3<Float>] = []

        var indices:
            [UInt32] = []


        addRibbon(
            points:
                points,
            width:
                width,
            vertices:
                &vertices,
            normals:
                &normals,
            indices:
                &indices
        )


        return createMeshResource(
            vertices:
                vertices,
            normals:
                normals,
            indices:
                indices,
            name:
                "ARRoadMesh"
        )
    }


    // MARK: - Create Mesh Resource

    private func createMeshResource(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        indices: [UInt32],
        name: String
    ) -> MeshResource? {

        guard !vertices.isEmpty,
              !indices.isEmpty
        else {
            return nil
        }


        var descriptor =
            MeshDescriptor(
                name:
                    name
            )


        descriptor.positions =
            MeshBuffers.Positions(
                vertices
            )


        descriptor.normals =
            MeshBuffers.Normals(
                normals
            )


        descriptor.primitives =
            .triangles(
                indices
            )


        do {

            return try MeshResource.generate(
                from: [
                    descriptor
                ]
            )

        } catch {

            print(
                "ARTrackRenderer: "
                + "Could not create mesh:",
                error
            )


            return nil
        }
    }


    // MARK: - Add Ribbon

    private func addRibbon(
        points: [SIMD3<Float>],
        width: Float,
        vertices: inout [SIMD3<Float>],
        normals: inout [SIMD3<Float>],
        indices: inout [UInt32]
    ) {

        guard points.count >= 2 else {
            return
        }


        let halfWidth =
            width / 2


        let firstVertexIndex =
            UInt32(
                vertices.count
            )


        // Create one left and one right
        // vertex for every path point.
        for index in
            points.indices {

            let side =
                sideVector(
                    at:
                        index,
                    points:
                        points
                )


            let offset =
                side
                * halfWidth


            let leftPoint =
                points[index]
                + offset

            let rightPoint =
                points[index]
                - offset


            vertices.append(
                leftPoint
            )

            vertices.append(
                rightPoint
            )


            normals.append(
                SIMD3<Float>(
                    0,
                    1,
                    0
                )
            )

            normals.append(
                SIMD3<Float>(
                    0,
                    1,
                    0
                )
            )
        }


        // Connect each pair using
        // two triangles.
        for index in
            0..<(points.count - 1) {

            let currentLeft =
                firstVertexIndex
                + UInt32(
                    index * 2
                )

            let currentRight =
                currentLeft + 1

            let nextLeft =
                currentLeft + 2

            let nextRight =
                currentLeft + 3


            indices.append(
                contentsOf: [

                    currentLeft,
                    nextLeft,
                    currentRight,

                    currentRight,
                    nextLeft,
                    nextRight
                ]
            )
        }
    }


    // MARK: - Offset Path

    /// Creates a parallel path to the original track.
    ///
    /// Positive values move to one side,
    /// negative values to the other side.
    private func offsetPath(
        _ path: [SIMD3<Float>],
        lateralOffset: Float,
        verticalOffset: Float
    ) -> [SIMD3<Float>] {

        guard path.count >= 2 else {
            return path
        }


        return path.indices.map {

            let side =
                sideVector(
                    at:
                        $0,
                    points:
                        path
                )


            var point =
                path[$0]
                + side
                * lateralOffset


            point.y +=
                verticalOffset


            return point
        }
    }


    // MARK: - Side Vector

    private func sideVector(
        at index: Int,
        points: [SIMD3<Float>]
    ) -> SIMD3<Float> {

        let tangent:
            SIMD3<Float>


        if index == 0 {

            tangent =
                normalizedDirection(
                    from:
                        points[0],
                    to:
                        points[1]
                )

        } else if index
                    == points.count - 1 {

            tangent =
                normalizedDirection(
                    from:
                        points[index - 1],
                    to:
                        points[index]
                )

        } else {

            let incoming =
                normalizedDirection(
                    from:
                        points[index - 1],
                    to:
                        points[index]
                )


            let outgoing =
                normalizedDirection(
                    from:
                        points[index],
                    to:
                        points[index + 1]
                )


            let combined =
                incoming
                + outgoing


            if simd_length(
                combined
            ) > 0.001 {

                tangent =
                    simd_normalize(
                        combined
                    )

            } else {

                tangent =
                    outgoing
            }
        }


        let side =
            SIMD3<Float>(
                -tangent.z,
                0,
                tangent.x
            )


        guard simd_length(
            side
        ) > 0.001
        else {

            return SIMD3<Float>(
                1,
                0,
                0
            )
        }


        return simd_normalize(
            side
        )
    }


    // MARK: - Segment Points

    private func points(
        fromDistance startDistance: Float,
        toDistance endDistance: Float,
        path: [SIMD3<Float>],
        cumulativeDistances: [Float]
    ) -> [SIMD3<Float>] {

        guard endDistance
                > startDistance
        else {
            return []
        }


        var result:
            [SIMD3<Float>] = []


        result.append(
            point(
                atDistance:
                    startDistance,
                path:
                    path,
                cumulativeDistances:
                    cumulativeDistances
            )
        )


        for index in
            1..<(path.count - 1) {

            let distance =
                cumulativeDistances[
                    index
                ]


            if distance
                > startDistance
                && distance
                < endDistance {

                result.append(
                    path[index]
                )
            }
        }


        let endPoint =
            point(
                atDistance:
                    endDistance,
                path:
                    path,
                cumulativeDistances:
                    cumulativeDistances
            )


        if let last =
            result.last {

            if simd_distance(
                last,
                endPoint
            ) > 0.0001 {

                result.append(
                    endPoint
                )
            }

        } else {

            result.append(
                endPoint
            )
        }


        return result
    }


    // MARK: - Point At Distance

    private func point(
        atDistance distance: Float,
        path: [SIMD3<Float>],
        cumulativeDistances: [Float]
    ) -> SIMD3<Float> {

        if distance <= 0 {
            return path[0]
        }


        if let totalDistance =
            cumulativeDistances.last,
           distance >= totalDistance {

            return path[
                path.count - 1
            ]
        }


        for index in
            0..<(path.count - 1) {

            let segmentStart =
                cumulativeDistances[
                    index
                ]

            let segmentEnd =
                cumulativeDistances[
                    index + 1
                ]


            if distance
                >= segmentStart
                && distance
                <= segmentEnd {

                let segmentLength =
                    segmentEnd
                    - segmentStart


                guard segmentLength
                        > 0.0001
                else {

                    return path[
                        index
                    ]
                }


                let progress =
                    (
                        distance
                        - segmentStart
                    )
                    / segmentLength


                return simd_mix(
                    path[index],
                    path[index + 1],
                    SIMD3<Float>(
                        repeating:
                            progress
                    )
                )
            }
        }


        return path[
            path.count - 1
        ]
    }


    // MARK: - Cumulative Distances

    private func calculateCumulativeDistances(
        for path: [SIMD3<Float>]
    ) -> [Float] {

        guard !path.isEmpty else {
            return []
        }


        var distances:
            [Float] = [0]

        var total:
            Float = 0


        for index in
            1..<path.count {

            total +=
                simd_distance(
                    path[index - 1],
                    path[index]
                )


            distances.append(
                total
            )
        }


        return distances
    }


    // MARK: - Direction

    private func normalizedDirection(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>
    ) -> SIMD3<Float> {

        let vector =
            end - start


        guard simd_length(
            vector
        ) > 0.0001
        else {

            return SIMD3<Float>(
                0,
                0,
                1
            )
        }


        return simd_normalize(
            vector
        )
    }
}
