//
//  MapPreviewView.swift
//  EdukARt
//
//

import ARKit
import RealityKit
import SwiftUI
import UIKit

struct MapPreviewView: View {
    let map: StoredFloorMap
    let onBack: () -> Void
    @State private var statusText = "Karte ausrichten"
    @State private var placementRequest = 0

    var body: some View {
        ZStack {
            MapPreviewARViewContainer(
                map: map,
                placementRequest: placementRequest,
                statusText: $statusText
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.72), .clear, .black.opacity(0.84)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button("Zurueck") {
                        onBack()
                    }
                    .buttonStyle(MapPreviewButtonStyle())

                    Spacer()

                    Text(statusText)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.65))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    Text(map.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(map.referenceTagName == nil
                         ? "Richte die Kamera auf den Boden und platziere die gespeicherte Karte an der aktuellen Position."
                         : "Richte die Kamera auf AprilTag #1. Die gespeicherte Karte wird automatisch an diesem Marker ausgerichtet.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.84))

                    if map.referenceTagName == nil {
                        Button("Karte hier platzieren") {
                            placementRequest += 1
                        }
                        .buttonStyle(MapPreviewPlaceButtonStyle())
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial.opacity(0.74))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct MapPreviewARViewContainer: UIViewRepresentable {
    let map: StoredFloorMap
    let placementRequest: Int
    @Binding var statusText: String

    func makeCoordinator() -> MapPreviewCoordinator {
        MapPreviewCoordinator(map: map, statusText: $statusText)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        if map.referenceTagName != nil {
            context.coordinator.configureReferenceTagDetection(on: configuration)
        }
        arView.session.delegate = context.coordinator
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        context.coordinator.attach(to: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.handlePlacementRequestIfNeeded(placementRequest)
    }
}

private final class MapPreviewCoordinator: NSObject, ARSessionDelegate {
    private let map: StoredFloorMap
    private var statusText: Binding<String>
    private weak var arView: ARView?
    private let overlayAnchor = AnchorEntity(world: .zero)
    private var handledPlacementRequest = 0
    private var renderedAnchorIdentifier: UUID?

    init(map: StoredFloorMap, statusText: Binding<String>) {
        self.map = map
        self.statusText = statusText
    }

    func attach(to arView: ARView) {
        self.arView = arView
        arView.scene.anchors.append(overlayAnchor)
    }

    func handlePlacementRequestIfNeeded(_ placementRequest: Int) {
        guard handledPlacementRequest != placementRequest else {
            return
        }

        handledPlacementRequest = placementRequest
        placeMapAtScreenCenter()
    }

    func configureReferenceTagDetection(on configuration: ARWorldTrackingConfiguration) {
        guard let requiredTagName = map.activeReferenceTagName else {
            statusText.wrappedValue = "Auf Boden ausrichten"
            return
        }

        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AprilTags", bundle: nil) else {
            return
        }

        let requiredImages = referenceImages.filter { $0.name == requiredTagName }
        guard requiredImages.isEmpty == false else {
            statusText.wrappedValue = "AprilTag-Asset fehlt"
            return
        }

        configuration.detectionImages = Set(requiredImages)
        configuration.maximumNumberOfTrackedImages = 1
        configuration.automaticImageScaleEstimationEnabled = false
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let requiredTagName = map.activeReferenceTagName else {
            return
        }

        guard let tagAnchor = frame.anchors
            .compactMap({ $0 as? ARImageAnchor })
            .first(where: { $0.referenceImage.name == requiredTagName }) else {
            if renderedAnchorIdentifier == nil {
                statusText.wrappedValue = "Suche AprilTag #1"
            }
            return
        }

        guard renderedAnchorIdentifier != tagAnchor.identifier else {
            return
        }

        renderedAnchorIdentifier = tagAnchor.identifier
        renderMap(relativeTo: tagAnchor.transform)
        statusText.wrappedValue = "Karte an Tag #1 ausgerichtet"
    }

    private func placeMapAtScreenCenter() {
        guard let arView else {
            return
        }

        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let results = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .horizontal)
        guard let firstResult = results.first else {
            statusText.wrappedValue = "Kein Boden gefunden"
            return
        }

        renderMap(relativeTo: firstResult.worldTransform)
        statusText.wrappedValue = "Karte platziert"
    }

    private func renderMap(relativeTo originTransform: simd_float4x4) {
        overlayAnchor.children.removeAll()

        let material = SimpleMaterial(
            color: UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 0.94),
            roughness: 1,
            isMetallic: false
        )

        for strip in buildPreviewStrips() {
            let local = SIMD4<Float>(strip.center.x, strip.center.y, strip.center.z, 1)
            let world = originTransform * local
            let mesh = MeshResource.generateBox(size: [strip.size.x, 0.004, strip.size.z])
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = SIMD3<Float>(world.x, world.y + 0.002, world.z)
            overlayAnchor.addChild(entity)
        }
    }

    private func buildPreviewStrips() -> [PreviewStrip] {
        let rows = Dictionary(grouping: map.floorTiles, by: { Int((Float($0.z) / map.floorTileSize).rounded()) })
        let sortedRows = rows.keys.sorted()
        var rowSpans: [PreviewRowSpan] = []

        for row in sortedRows {
            guard let rowTiles = rows[row], rowTiles.isEmpty == false else {
                continue
            }

            let tilesByX = Dictionary(grouping: rowTiles, by: { Int((Float($0.x) / map.floorTileSize).rounded()) })
            let sortedXValues = tilesByX.keys.sorted()
            var runStart: Int?
            var previousX: Int?
            var runHeights: [Float] = []

            func flushRun() {
                guard let runStart, let previousX, runHeights.isEmpty == false else {
                    return
                }

                let averageY = runHeights.reduce(0, +) / Float(runHeights.count)
                rowSpans.append(PreviewRowSpan(z: row, minX: runStart, maxX: previousX, y: averageY))
                selfResetRun()
            }

            func selfResetRun() {
                runStart = nil
                previousX = nil
                runHeights = []
            }

            for x in sortedXValues {
                let heights = tilesByX[x]?.map(\.y) ?? []
                let height = heights.isEmpty ? 0 : heights.reduce(0, +) / Float(heights.count)

                if let currentPreviousX = previousX, x == currentPreviousX + 1 {
                    previousX = x
                    runHeights.append(height)
                } else {
                    flushRun()
                    runStart = x
                    previousX = x
                    runHeights = [height]
                }
            }

            flushRun()
        }

        var strips: [PreviewStrip] = []
        var currentSpan: PreviewRowSpan?

        func flushCurrentSpan() {
            guard let currentSpan else {
                return
            }

            let widthInTiles = currentSpan.maxX - currentSpan.minX + 1
            let depthInRows = currentSpan.endZ - currentSpan.z + 1
            let centerX = Float(currentSpan.minX + currentSpan.maxX) * 0.5 * map.floorTileSize
            let centerZ = Float(currentSpan.z + currentSpan.endZ) * 0.5 * map.floorTileSize

            strips.append(
                PreviewStrip(
                    center: SIMD3<Float>(centerX, currentSpan.y, centerZ),
                    size: SIMD3<Float>(
                        Float(widthInTiles) * map.floorTileSize,
                        0.004,
                        Float(depthInRows) * map.floorTileSize
                    )
                )
            )
        }

        for span in rowSpans {
            if var mergedSpan = currentSpan,
               mergedSpan.endZ + 1 == span.z,
               mergedSpan.minX == span.minX,
               mergedSpan.maxX == span.maxX {
                mergedSpan.endZ = span.z
                mergedSpan.y = min(mergedSpan.y, span.y)
                currentSpan = mergedSpan
            } else {
                flushCurrentSpan()
                currentSpan = span
            }
        }

        flushCurrentSpan()
        return strips
    }
}

private struct PreviewRowSpan {
    let z: Int
    var endZ: Int
    let minX: Int
    let maxX: Int
    var y: Float

    init(z: Int, minX: Int, maxX: Int, y: Float) {
        self.z = z
        self.endZ = z
        self.minX = minX
        self.maxX = maxX
        self.y = y
    }
}

private struct PreviewStrip {
    let center: SIMD3<Float>
    let size: SIMD3<Float>
}

private struct MapPreviewButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.65))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}

private struct MapPreviewPlaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.green.opacity(configuration.isPressed ? 0.78 : 0.92))
            )
            .foregroundStyle(.black)
    }
}
