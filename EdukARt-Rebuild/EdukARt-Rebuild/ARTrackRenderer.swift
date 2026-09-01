//
//  ARTrackRenderer.swift
//  EdukARt-Rebuild
//
//  Renders the stored 2D race track in RealityKit.
//
//  The renderer first creates one clean and uniformly
//  sampled center path from the stored track points.
//
//  Rendering pipeline:
//
//  Stored track points
//      ↓
//  Remove points that are too close
//      ↓
//  Smooth path using Chaikin corner cutting
//      ↓
//  Resample at a constant physical distance
//      ↓
//  Render:
//      - semi-transparent road surface
//      - dashed white center line
//      - continuous white road boundaries
//
//  The road and its markings use mitered ribbon geometry.
//  This avoids distorted or overlapping inner/outer
//  boundaries in curves.
//

import RealityKit
import simd
import UIKit


final class ARTrackRenderer {

    // ======================================================
    // MARK: - Road Settings
    // ======================================================

    /// Complete road width.
    private let roadWidth:
        Float = 0.60

    /// Distance from center to road boundary.
    private var roadHalfWidth:
        Float {

        roadWidth / 2
    }

    /// Transparency of the black road surface.
    private let roadOpacity:
        Float = 0.10

    /// Width of the continuous white road edge.
    private let roadEdgeWidth:
        Float = 0.035

    private let roadEdgeOpacity:
        Float = 0.80


    // ======================================================
    // MARK: - Center Line Settings
    // ======================================================

    private let centerLineWidth:
        Float = 0.035

    private let centerDashLength:
        Float = 0.30

    private let centerGapLength:
        Float = 0.10


    // ======================================================
    // MARK: - Path Processing
    // ======================================================

    /// Ignore stored points closer than this distance.
    ///
    /// This removes tiny finger-input irregularities.
    private let minimumInputPointDistance:
        Float = 0.015

    /// Number of smoothing passes.
    ///
    /// 2–3 usually gives a visibly smoother road
    /// without changing the original course too much.
    private let smoothingIterations:
        Int = 2

    /// Physical distance between final center-path samples.
    ///
    /// The complete renderer uses this normalized path.
    private let pathSampleDistance:
        Float = 0.02


    // ======================================================
    // MARK: - Geometry Settings
    // ======================================================

    /// Prevents extremely long miter joins
    /// if an unusually sharp corner remains.
    private let maximumMiterFactor:
        Float = 3.0


    // ======================================================
    // MARK: - Height Settings
    // ======================================================

    /// Base height above mapped floor.
    private let floorOffset:
        Float = 0.006

    /// Markings sit slightly above the road.
    private let lineOffset:
        Float = 0.001


    // ======================================================
    // MARK: - Start Settings
    // ======================================================

    private let startLineDistance:
        Float = 0.30


    // ======================================================
    // MARK: - Render Track
    // ======================================================

    func render(
        trackPoints: [StoredTrackPoint],
        aprilTags: [StoredAprilTag] = [],
        parent: Entity
    ) {

        guard trackPoints.count >= 2 else {
            return
        }


        // --------------------------------------------------
        // Remove previously rendered track
        // --------------------------------------------------

        parent
            .findEntity(
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


        // --------------------------------------------------
        // Convert persistent 2D track into 3D coordinates
        // --------------------------------------------------

        let rawPath =
            trackPoints.map {

                SIMD3<Float>(
                    $0.x,
                    floorOffset,
                    $0.z
                )
            }


        // --------------------------------------------------
        // Create one normalized center path
        // --------------------------------------------------

        let path =
            preparePath(
                rawPath
            )


        guard path.count >= 2 else {
            return
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


        // --------------------------------------------------
        // 1. Road
        // --------------------------------------------------

        renderRoad(
            path:
                path,
            parent:
                trackRoot
        )


        // --------------------------------------------------
        // 2. Dashed center line
        // --------------------------------------------------

        // Center line is intentionally hidden in gameplay for now.
        // renderCenterLine(
        //     path:
        //         path,
        //     cumulativeDistances:
        //         cumulativeDistances,
        //     totalLength:
        //         totalLength,
        //     parent:
        //         trackRoot
        // )


        // --------------------------------------------------
        // 3. Road boundaries
        // --------------------------------------------------

        renderRoadEdges(
            path:
                path,
            parent:
                trackRoot
        )


        // --------------------------------------------------
        // 4. Start
        // --------------------------------------------------

        renderStartLine(
            path:
                path,
            aprilTags:
                aprilTags,
            parent:
                trackRoot
        )
    }


    // ======================================================
    // MARK: - Prepare Path
    // ======================================================

    /// Creates the single center path that is used
    /// by every rendered road component.
    private func preparePath(
        _ input: [SIMD3<Float>]
    ) -> [SIMD3<Float>] {

        // 1. Remove extremely close points.
        var path =
            removeClosePoints(
                input,
                minimumDistance:
                    minimumInputPointDistance
            )


        guard path.count >= 2 else {
            return path
        }


        // 2. Smooth the original polyline.
        for _ in 0..<smoothingIterations {

            path =
                chaikinSmooth(
                    path
                )
        }


        // 3. Sample the final line at constant
        // physical distances.
        path =
            resamplePath(
                path,
                spacing:
                    pathSampleDistance
            )


        return path
    }


    // ======================================================
    // MARK: - Remove Close Points
    // ======================================================

    private func removeClosePoints(
        _ points: [SIMD3<Float>],
        minimumDistance: Float
    ) -> [SIMD3<Float>] {

        guard let first =
            points.first
        else {
            return []
        }


        var result:
            [SIMD3<Float>] = [
                first
            ]


        for point in points.dropFirst() {

            guard let previous =
                result.last
            else {
                continue
            }


            if horizontalDistance(
                previous,
                point
            ) >= minimumDistance {

                result.append(
                    point
                )
            }
        }


        // Always keep original end point.
        if let last =
            points.last,
           let currentLast =
            result.last,
           horizontalDistance(
                currentLast,
                last
           ) > 0.001 {

            result.append(
                last
            )
        }


        return result
    }


    // ======================================================
    // MARK: - Chaikin Smoothing
    // ======================================================

    /// Smooths a polyline without spline overshoot.
    ///
    /// Every corner is replaced by two points:
    ///
    /// P0 ---- Q ---- R ---- P1
    ///
    /// Q = 75% P0 + 25% P1
    /// R = 25% P0 + 75% P1
    ///
    /// Start and end remain unchanged.
    private func chaikinSmooth(
        _ points: [SIMD3<Float>]
    ) -> [SIMD3<Float>] {

        guard points.count >= 3 else {
            return points
        }


        var result:
            [SIMD3<Float>] = []


        // Keep start point.
        result.append(
            points[0]
        )


        for index in
            0..<(points.count - 1) {

            let p0 =
                points[index]

            let p1 =
                points[index + 1]


            let q =
                p0 * 0.75
                + p1 * 0.25

            let r =
                p0 * 0.25
                + p1 * 0.75


            // Avoid duplicating points very close
            // to the preserved start/end.
            if index > 0 {

                result.append(
                    q
                )
            }


            if index <
                points.count - 2 {

                result.append(
                    r
                )
            }
        }


        // Keep end point.
        result.append(
            points[
                points.count - 1
            ]
        )


        return result
    }


    // ======================================================
    // MARK: - Resample Path
    // ======================================================

    /// Samples the path at approximately equal
    /// physical distances.
    private func resamplePath(
        _ path: [SIMD3<Float>],
        spacing: Float
    ) -> [SIMD3<Float>] {

        guard path.count >= 2,
              spacing > 0
        else {
            return path
        }


        let distances =
            calculateCumulativeDistances(
                for: path
            )


        guard let totalLength =
            distances.last,
              totalLength > 0
        else {
            return path
        }


        var result:
            [SIMD3<Float>] = []


        var distance:
            Float = 0


        while distance < totalLength {

            result.append(
                point(
                    atDistance:
                        distance,
                    path:
                        path,
                    cumulativeDistances:
                        distances
                )
            )


            distance +=
                spacing
        }


        // Always preserve the final point.
        if let last =
            path.last {

            if let currentLast =
                result.last {

                if horizontalDistance(
                    currentLast,
                    last
                ) > 0.001 {

                    result.append(
                        last
                    )
                }

            } else {

                result.append(
                    last
                )
            }
        }


        return result
    }


    // ======================================================
    // MARK: - Road
    // ======================================================

    private func renderRoad(
        path: [SIMD3<Float>],
        parent: Entity
    ) {

        guard let mesh =
            createRibbonMesh(
                points:
                    path,
                width:
                    roadWidth
            )
        else {
            return
        }


        let material =
            UnlitMaterial(
                color:
                    .black
            )


        let entity =
            ModelEntity(
                mesh:
                    mesh,
                materials:
                    [
                        material
                    ]
            )


        entity.name =
            "ARRoadSurface"


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


    // ======================================================
    // MARK: - Center Line
    // ======================================================

    private func renderCenterLine(
        path: [SIMD3<Float>],
        cumulativeDistances: [Float],
        totalLength: Float,
        parent: Entity
    ) {

        let elevatedPath =
            path.map {

                SIMD3<Float>(
                    $0.x,
                    $0.y
                        + lineOffset,
                    $0.z
                )
            }


        guard let mesh =
            createDashedMesh(
                path:
                    elevatedPath,
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


        let entity =
            ModelEntity(
                mesh:
                    mesh,
                materials:
                    [
                        UnlitMaterial(
                            color:
                                .white
                        )
                    ]
            )


        entity.name =
            "ARCenterLine"


        parent.addChild(
            entity
        )
    }


    // ======================================================
    // MARK: - Road Edges
    // ======================================================

    private func renderRoadEdges(
        path: [SIMD3<Float>],
        parent: Entity
    ) {

        let leftPath =
            createOffsetPath(
                from:
                    path,
                distance:
                    roadHalfWidth,
                verticalOffset:
                    lineOffset * 2
            )


        let rightPath =
            createOffsetPath(
                from:
                    path,
                distance:
                    -roadHalfWidth,
                verticalOffset:
                    lineOffset * 2
            )


        renderRoadEdge(
            path:
                leftPath,
            name:
                "ARLeftRoadEdge",
            parent:
                parent
        )


        renderRoadEdge(
            path:
                rightPath,
            name:
                "ARRightRoadEdge",
            parent:
                parent
        )
    }


    private func renderRoadEdge(
        path: [SIMD3<Float>],
        name: String,
        parent: Entity
    ) {

        guard let mesh =
            createRibbonMesh(
                points:
                    path,
                width:
                    roadEdgeWidth
            )
        else {
            return
        }


        let entity =
            ModelEntity(
                mesh:
                    mesh,
                materials:
                    [
                        UnlitMaterial(
                            color:
                                .white
                        )
                    ]
            )


        entity.name =
            name

        entity.components.set(
            OpacityComponent(
                opacity:
                    roadEdgeOpacity
            )
        )


        parent.addChild(
            entity
        )
    }


    // ======================================================
    // MARK: - Offset Path
    // ======================================================

    /// Creates a parallel path using miter joins.
    ///
    /// This is the important difference from simply
    /// adding `sideVector * distance` to every point.
    private func createOffsetPath(
        from path: [SIMD3<Float>],
        distance: Float,
        verticalOffset: Float
    ) -> [SIMD3<Float>] {

        guard path.count >= 2 else {
            return path
        }


        var result:
            [SIMD3<Float>] = []


        for index in path.indices {

            let offset =
                miterOffset(
                    at:
                        index,
                    points:
                        path,
                    distance:
                        distance
                )


            var point =
                path[index]
                + offset


            point.y +=
                verticalOffset


            result.append(
                point
            )
        }


        return result
    }


    // ======================================================
    // MARK: - Miter Offset
    // ======================================================

    private func miterOffset(
        at index: Int,
        points: [SIMD3<Float>],
        distance: Float
    ) -> SIMD3<Float> {

        guard points.count >= 2 else {
            return .zero
        }


        // --------------------------------------------------
        // Start
        // --------------------------------------------------

        if index == 0 {

            return sideVector(
                from:
                    points[0],
                to:
                    points[1]
            )
            * distance
        }


        // --------------------------------------------------
        // End
        // --------------------------------------------------

        if index ==
            points.count - 1 {

            return sideVector(
                from:
                    points[index - 1],
                to:
                    points[index]
            )
            * distance
        }


        // --------------------------------------------------
        // Interior vertex
        // --------------------------------------------------

        let previousSide =
            sideVector(
                from:
                    points[index - 1],
                to:
                    points[index]
            )


        let nextSide =
            sideVector(
                from:
                    points[index],
                to:
                    points[index + 1]
            )


        let combined =
            previousSide
            + nextSide


        guard simd_length(
            combined
        ) > 0.0001
        else {

            return nextSide
                * distance
        }


        let miter =
            simd_normalize(
                combined
            )


        let denominator =
            simd_dot(
                miter,
                nextSide
            )


        guard abs(
            denominator
        ) > 0.05
        else {

            return nextSide
                * distance
        }


        var miterLength =
            distance
            / denominator


        // Prevent spikes at very sharp corners.
        let maximumLength =
            abs(distance)
            * maximumMiterFactor


        miterLength =
            min(
                max(
                    miterLength,
                    -maximumLength
                ),
                maximumLength
            )


        return miter
            * miterLength
    }


    // ======================================================
    // MARK: - Side Vector
    // ======================================================

    private func sideVector(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>
    ) -> SIMD3<Float> {

        var direction =
            end - start


        // Geometry is always planar.
        direction.y =
            0


        guard simd_length(
            direction
        ) > 0.0001
        else {

            return SIMD3<Float>(
                1,
                0,
                0
            )
        }


        direction =
            simd_normalize(
                direction
            )


        return SIMD3<Float>(
            -direction.z,
            0,
            direction.x
        )
    }


    // ======================================================
    // MARK: - Dashed Mesh
    // ======================================================

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


        while dashStart < totalLength {

            let dashEnd =
                min(
                    dashStart
                        + dashLength,
                    totalLength
                )


            let dashPath =
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
                    dashPath,
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


    // ======================================================
    // MARK: - Ribbon Mesh
    // ======================================================

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
                "ARRibbonMesh"
        )
    }


    // ======================================================
    // MARK: - Add Ribbon
    // ======================================================

    /// Creates a ribbon around a path.
    ///
    /// Every path point receives a mitered left/right
    /// vertex pair instead of a simple perpendicular pair.
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


        // --------------------------------------------------
        // Vertices
        // --------------------------------------------------

        for index in points.indices {

            let offset =
                miterOffset(
                    at:
                        index,
                    points:
                        points,
                    distance:
                        halfWidth
                )


            let left =
                points[index]
                + offset

            let right =
                points[index]
                - offset


            vertices.append(
                left
            )

            vertices.append(
                right
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


        // --------------------------------------------------
        // Triangles
        // --------------------------------------------------

        for index in
            0..<(points.count - 1) {

            let currentLeft =
                firstVertexIndex
                + UInt32(
                    index * 2
                )

            let currentRight =
                currentLeft
                + 1

            let nextLeft =
                currentLeft
                + 2

            let nextRight =
                currentLeft
                + 3


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


    // ======================================================
    // MARK: - Mesh Resource
    // ======================================================

    private func createMeshResource(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        indices: [UInt32],
        name: String
    ) -> MeshResource? {

        guard vertices.isEmpty == false,
              indices.isEmpty == false
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
                from:
                    [
                        descriptor
                    ]
            )

        } catch {

            print(
                "ARTrackRenderer: Could not create mesh:",
                error
            )

            return nil
        }
    }


    // ======================================================
    // MARK: - Segment Between Distances
    // ======================================================

    private func points(
        fromDistance startDistance: Float,
        toDistance endDistance: Float,
        path: [SIMD3<Float>],
        cumulativeDistances: [Float]
    ) -> [SIMD3<Float>] {

        guard endDistance >
                startDistance
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


            if distance >
                startDistance
                &&
                distance <
                endDistance {

                result.append(
                    path[index]
                )
            }
        }


        let end =
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

            if horizontalDistance(
                last,
                end
            ) > 0.0001 {

                result.append(
                    end
                )
            }

        } else {

            result.append(
                end
            )
        }


        return result
    }


    // ======================================================
    // MARK: - Point At Distance
    // ======================================================

    private func point(
        atDistance distance: Float,
        path: [SIMD3<Float>],
        cumulativeDistances: [Float]
    ) -> SIMD3<Float> {

        if distance <= 0 {
            return path[0]
        }


        if let total =
            cumulativeDistances.last,
           distance >= total {

            return path[
                path.count - 1
            ]
        }


        for index in
            0..<(path.count - 1) {

            let startDistance =
                cumulativeDistances[
                    index
                ]

            let endDistance =
                cumulativeDistances[
                    index + 1
                ]


            if distance >=
                startDistance
                &&
                distance <=
                endDistance {

                let segmentLength =
                    endDistance
                    - startDistance


                guard segmentLength >
                        0.0001
                else {

                    return path[
                        index
                    ]
                }


                let progress =
                    (
                        distance
                        - startDistance
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


    // ======================================================
    // MARK: - Cumulative Distances
    // ======================================================

    private func calculateCumulativeDistances(
        for path: [SIMD3<Float>]
    ) -> [Float] {

        guard path.isEmpty == false else {
            return []
        }


        var result:
            [Float] = [
                0
            ]


        var total:
            Float = 0


        for index in
            1..<path.count {

            total +=
                horizontalDistance(
                    path[index - 1],
                    path[index]
                )


            result.append(
                total
            )
        }


        return result
    }


    // ======================================================
    // MARK: - Horizontal Distance
    // ======================================================

    private func horizontalDistance(
        _ first: SIMD3<Float>,
        _ second: SIMD3<Float>
    ) -> Float {

        let dx =
            second.x
            - first.x

        let dz =
            second.z
            - first.z


        return sqrt(
            dx * dx
            +
            dz * dz
        )
    }


    // ======================================================
    // MARK: - Direction
    // ======================================================

    private func normalizedDirection(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>
    ) -> SIMD3<Float> {

        var vector =
            end
            - start


        vector.y =
            0


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


    // ======================================================
    // MARK: - Start Line
    // ======================================================

    private func renderStartLine(
        path: [SIMD3<Float>],
        aprilTags: [StoredAprilTag],
        parent: Entity
    ) {

        guard path.count >= 2 else {
            return
        }


        let direction =
            normalizedDirection(
                from:
                    path[0],
                to:
                    path[1]
            )


        let referencePoint:
            SIMD3<Float>


        if let firstTag =
            aprilTags.first {

            referencePoint =
                SIMD3<Float>(
                    firstTag.x,
                    floorOffset
                        + lineOffset * 2,
                    firstTag.z
                )

        } else {

            referencePoint =
                path[0]
        }


        let origin =
            referencePoint
            - direction
            * startLineDistance


        addStartText(
            origin:
                origin
                + direction
                * 0.18,
            direction:
                direction,
            parent:
                parent
        )
    }


    // ======================================================
    // MARK: - Start Text
    // ======================================================

    private func addStartText(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        parent: Entity
    ) {

        let mesh =
            MeshResource.generateText(
                "Start",
                extrusionDepth:
                    0.001,
                font:
                    .boldSystemFont(
                        ofSize:
                            0.10
                    ),
                containerFrame:
                    .zero,
                alignment:
                    .center,
                lineBreakMode:
                    .byWordWrapping
            )


        let entity =
            ModelEntity(
                mesh:
                    mesh,
                materials:
                    [
                        UnlitMaterial(
                            color:
                                .white
                        )
                    ]
            )


        entity.name =
            "ARStartText"

        entity.position =
            origin


        let trackOrientation =
            simd_quatf(
                from:
                    SIMD3<Float>(
                        1,
                        0,
                        0
                    ),
                to:
                    direction
            )


        let turn =
            simd_quatf(
                angle:
                    -.pi / 2,
                axis:
                    SIMD3<Float>(
                        0,
                        1,
                        0
                    )
            )


        entity.orientation =
            turn
            * trackOrientation


        parent.addChild(
            entity
        )
    }
}
