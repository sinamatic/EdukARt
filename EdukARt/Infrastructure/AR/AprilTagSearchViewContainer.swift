//
//  AprilTagSearchViewContainer.swift
//  EdukARt
//
//

import ARKit
import RealityKit
import SwiftUI
import UIKit

struct AprilTagSearchViewContainer: UIViewRepresentable {
    @ObservedObject var session: AprilTagSearchSession

    func makeCoordinator() -> AprilTagSearchCoordinator {
        AprilTagSearchCoordinator(session: session)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        arView.backgroundColor = .black
        context.coordinator.attach(to: arView)
        context.coordinator.startSessionIfNeeded()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.session = session
        context.coordinator.attach(to: uiView)
        context.coordinator.startSessionIfNeeded()
    }
}

final class AprilTagSearchCoordinator: NSObject, ARSessionDelegate {
    var session: AprilTagSearchSession

    private weak var arView: ARView?
    private let overlayView = AprilTagOverlayView()
    private var hasStartedSession = false

    init(session: AprilTagSearchSession) {
        self.session = session
    }

    func attach(to arView: ARView) {
        self.arView = arView
        arView.session.delegate = self

        if overlayView.superview !== arView {
            overlayView.translatesAutoresizingMaskIntoConstraints = false
            overlayView.isUserInteractionEnabled = false
            arView.addSubview(overlayView)

            NSLayoutConstraint.activate([
                overlayView.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
                overlayView.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
                overlayView.topAnchor.constraint(equalTo: arView.topAnchor),
                overlayView.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
            ])
        }
    }

    func startSessionIfNeeded() {
        guard hasStartedSession == false, let arView else {
            return
        }

        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AprilTags", bundle: nil),
              referenceImages.isEmpty == false else {
            Task { @MainActor [weak self] in
                self?.session.setMissingAssetsMessage()
            }
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []
        configuration.environmentTexturing = .none
        configuration.detectionImages = referenceImages
        configuration.maximumNumberOfTrackedImages = min(referenceImages.count, 3)
        configuration.isAutoFocusEnabled = true
        configuration.automaticImageScaleEstimationEnabled = false

        Task { @MainActor [weak self] in
            self?.session.setSearchingMessage()
        }

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        hasStartedSession = true
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let arView else {
            return
        }

        let trackedAnchors = frame.anchors
            .compactMap { $0 as? ARImageAnchor }
            .filter { $0.isTracked }

        if trackedAnchors.isEmpty == false {
            let detections = trackedAnchors.map { trackedAnchor in
                AprilTagOverlayDetection(
                    corners: projectedCorners(for: trackedAnchor, in: arView, frame: frame),
                    label: self.session.displayNumber(for: trackedAnchor.referenceImage.name ?? "AprilTag")
                )
            }
            let tagNames = trackedAnchors.map { $0.referenceImage.name ?? "AprilTag" }

            Task { @MainActor [weak self] in
                self?.session.updateDetection(tagNames: tagNames, isTracked: true)
                self?.overlayView.update(detections: detections)
            }
        } else {
            Task { @MainActor [weak self] in
                self?.session.updateDetection(tagNames: [], isTracked: false)
                self?.overlayView.clear()
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.session.setFailureMessage(error.localizedDescription)
            self?.overlayView.clear()
            
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor [weak self] in
            self?.session.setFailureMessage("Kamera wurde unterbrochen")
            self?.overlayView.clear()
        }
    }

    private func projectedCorners(for anchor: ARImageAnchor, in arView: ARView, frame: ARFrame) -> [CGPoint] {
        let physicalSize = anchor.referenceImage.physicalSize
        let halfWidth = Float(physicalSize.width / 2)
        let halfHeight = Float(physicalSize.height / 2)

        let localCorners = [
            SIMD4<Float>(-halfWidth, 0, -halfHeight, 1),
            SIMD4<Float>(halfWidth, 0, -halfHeight, 1),
            SIMD4<Float>(halfWidth, 0, halfHeight, 1),
            SIMD4<Float>(-halfWidth, 0, halfHeight, 1)
        ]

        let orientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait
        let viewportSize = arView.bounds.size

        return localCorners.map { localCorner in
            let worldCorner = anchor.transform * localCorner
            return frame.camera.projectPoint(
                SIMD3<Float>(worldCorner.x, worldCorner.y, worldCorner.z),
                orientation: orientation,
                viewportSize: viewportSize
            )
        }
    }
}

final class AprilTagOverlayView: UIView {
    private let shapeLayer = CAShapeLayer()
    private var labelBackgroundViews: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        shapeLayer.strokeColor = UIColor.systemYellow.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 4
        shapeLayer.lineJoin = .round
        layer.addSublayer(shapeLayer)

    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(corners: [CGPoint], label: String) {
        update(detections: [AprilTagOverlayDetection(corners: corners, label: label)])
    }

    func update(detections: [AprilTagOverlayDetection]) {
        removeLabels()

        guard detections.isEmpty == false else {
            clear()
            return
        }

        let combinedPath = UIBezierPath()
        for detection in detections {
            addPath(for: detection.corners, to: combinedPath)
            addLabel(detection.label, corners: detection.corners)
        }

        shapeLayer.path = combinedPath.cgPath
        shapeLayer.isHidden = false
    }

    private func addPath(for corners: [CGPoint], to combinedPath: UIBezierPath) {
        guard corners.count == 4 else {
            return
        }

        combinedPath.move(to: corners[0])
        combinedPath.addLine(to: corners[1])
        combinedPath.addLine(to: corners[2])
        combinedPath.addLine(to: corners[3])
        combinedPath.close()
    }

    private func addLabel(_ text: String, corners: [CGPoint]) {
        guard corners.count == 4 else {
            return
        }

        let labelBackgroundView = UIView()
        labelBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        labelBackgroundView.layer.cornerRadius = 12
        addSubview(labelBackgroundView)

        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .bold)
        label.text = text
        label.textColor = .white
        label.textAlignment = .center
        label.sizeToFit()
        labelBackgroundView.addSubview(label)

        let topPoint = corners.min(by: { $0.y < $1.y }) ?? corners[0]
        let labelWidth = max(label.bounds.width + 20, 62)
        let labelHeight: CGFloat = 34
        let originX = min(max(topPoint.x - (labelWidth / 2), 12), bounds.width - labelWidth - 12)
        let originY = max(topPoint.y - labelHeight - 12, 12)

        labelBackgroundView.frame = CGRect(x: originX, y: originY, width: labelWidth, height: labelHeight)
        label.frame = labelBackgroundView.bounds
        labelBackgroundViews.append(labelBackgroundView)
    }

    func clear() {
        shapeLayer.path = nil
        shapeLayer.isHidden = true
        removeLabels()
    }

    private func removeLabels() {
        labelBackgroundViews.forEach { $0.removeFromSuperview() }
        labelBackgroundViews = []
    }
}

struct AprilTagOverlayDetection {
    let corners: [CGPoint]
    let label: String
}
