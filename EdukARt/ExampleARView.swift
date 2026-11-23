import ARKit
import Combine
import RealityKit
import SwiftUI
import SwiftUIJoystick

struct ExampleARView: View {
    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var controller: RobotController

    @StateObject private var joystickMonitor = JoystickMonitor()
    @StateObject private var turnJoystickMonitor = JoystickMonitor()
    @State private var isPlaced = false
    @State private var canPlaceTrack = false
    @State private var showsItemGuidance = false
    @State private var isARMenuOpen = false
    @State private var exampleTrack = ExampleTrack()

    var body: some View {
        ZStack(alignment: .topLeading) {
            ExampleARScene(
                eduardModelStore: eduardModelStore,
                controller: controller,
                exampleTrack: exampleTrack,
                isPlaced: $isPlaced,
                canPlaceTrack: $canPlaceTrack
            )
            .ignoresSafeArea()

            GameMinimapPanel(
                map: nil,
                robotPose: nil,
                simulationPose: nil,
                runtimeMapObjects: nil,
                shitDots: [],
                isLocalized: true,
                coinCount: nil
            )

            if !isPlaced || showsItemGuidance {
                Group {
                    if isPlaced {
                        Text("Use the right joystick to drive forward and sideways, and the left joystick to rotate. To use item effects, print and place AprilTags and create a map.")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(16)
                            .frame(maxWidth: 340)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("Example Mode. Print AprilTags for gameplay and create a map.")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(16)
                            .frame(maxWidth: 340)
                            .background(
                                .black.opacity(0.75),
                                in: UnevenRoundedRectangle(
                                    topLeadingRadius: 12,
                                    bottomLeadingRadius: canPlaceTrack ? 0 : 12,
                                    bottomTrailingRadius: canPlaceTrack ? 0 : 12,
                                    topTrailingRadius: 12
                                )
                            )
                            .overlay {
                                GeometryReader { geometry in
                                    if canPlaceTrack && eduardModelStore.model != nil {
                                        Text("Tap anywhere on the floor to place a small track with AR elements.")
                                            .font(.headline)
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.bottom, 16)
                                            .frame(width: geometry.size.width)
                                            .background(
                                                .black.opacity(0.75),
                                                in: UnevenRoundedRectangle(
                                                    topLeadingRadius: 0,
                                                    bottomLeadingRadius: 12,
                                                    bottomTrailingRadius: 12,
                                                    topTrailingRadius: 0
                                                )
                                            )
                                            .offset(y: geometry.size.height)
                                    }
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .allowsHitTesting(false)
            }

            GameARMenu(
                isOpen: $isARMenuOpen,
                isSimulationVisible: controller.isSimulationVisible,
                isLiveSyncEnabled: false,
                canPlaceOnStart: isPlaced,
                canShowAR: isPlaced,
                isExample: true,
                topInset: 28,
                onPlaceOnStart: {
                    if let start = ARTrackRenderer().startLinePose(for: exampleTrack.trackPoints) {
                        controller.placeSimulationAtStartLine(start)
                        if !controller.isSimulationVisible {
                            controller.toggleSimulationVisibility()
                        }
                    }
                },
                onSync: {},
                onToggleLiveSync: {},
                onToggleAR: { controller.toggleSimulationVisibility() }
            )

            if isPlaced {
                GameJoystickControls(
                    joystickMonitor: joystickMonitor,
                    turnJoystickMonitor: turnJoystickMonitor,
                    controller: controller,
                    isEnabled: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 30)

                GameStatusBar(
                    timeText: nil,
                    speedPercent: controller.currentSpeedPercent,
                    damageCount: nil
                )
            }
        }
        .navigationTitle("Example AR")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: isPlaced) {
            showsItemGuidance = false
            guard isPlaced else { return }
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                showsItemGuidance = true
            }
        }
        .onAppear {
            controller.controlMode = .simulation
            controller.isLiveSyncEnabled = false
            controller.resetForManualControl()
            Task { await eduardModelStore.load() }
        }
        .onDisappear {
            controller.stopJoystick()
            controller.stopMechanumRotation()
            controller.eduardSimulation.stop()
        }
    }
}

private struct ExampleARScene: UIViewRepresentable {
    let eduardModelStore: EduardModelStore
    let controller: RobotController
    let exampleTrack: ExampleTrack
    @Binding var isPlaced: Bool
    @Binding var canPlaceTrack: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            eduardModelStore: eduardModelStore,
            controller: controller,
            exampleTrack: exampleTrack,
            isPlaced: $isPlaced,
            canPlaceTrack: $canPlaceTrack
        )
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(
            frame: .zero,
            cameraMode: .ar,
            automaticallyConfigureSession: false
        )
        context.coordinator.arView = view
        view.session.delegate = context.coordinator

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        view.session.run(configuration)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.placeAtTap(_:))
        )
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.cleanUp()
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        let eduardModelStore: EduardModelStore
        let controller: RobotController
        let exampleTrack: ExampleTrack
        let isPlaced: Binding<Bool>
        let canPlaceTrack: Binding<Bool>
        weak var arView: ARView?

        private var floorAnchor: AnchorEntity?
        private var enabledSimulationVisibility = false
        private let coinRenderer = ARCoinRenderer()
        private var animatedObjects: [ARAnimatedMapObject] = []
        private var animationTime: Float = 0
        private var animationSubscription: Cancellable?

        init(
            eduardModelStore: EduardModelStore,
            controller: RobotController,
            exampleTrack: ExampleTrack,
            isPlaced: Binding<Bool>,
            canPlaceTrack: Binding<Bool>
        ) {
            self.eduardModelStore = eduardModelStore
            self.controller = controller
            self.exampleTrack = exampleTrack
            self.isPlaced = isPlaced
            self.canPlaceTrack = canPlaceTrack
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard anchors.contains(where: {
                guard let plane = $0 as? ARPlaneAnchor else { return false }
                return plane.alignment == .horizontal
            }) else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.floorAnchor == nil else { return }
                self.canPlaceTrack.wrappedValue = true
            }
        }

        @objc func placeAtTap(_ gesture: UITapGestureRecognizer) {
            guard floorAnchor == nil,
                  let view = arView,
                  let hit = view.raycast(
                    from: gesture.location(in: view),
                    allowing: .existingPlaneGeometry,
                    alignment: .horizontal
                  ).first,
                  let cameraTransform = view.session.currentFrame?.camera.transform,
                  let model = eduardModelStore.model
            else {
                return
            }

            controller.controlMode = .simulation
            controller.isLiveSyncEnabled = false

            let position = hit.worldTransform.columns.3
            let cameraForward = -cameraTransform.columns.2
            let yaw = atan2(-cameraForward.x, -cameraForward.z)
            let anchor = AnchorEntity(
                world: SIMD3<Float>(position.x, position.y, position.z)
            )
            anchor.orientation = simd_quatf(
                angle: yaw,
                axis: SIMD3<Float>(0, 1, 0)
            )

            ARTrackRenderer().render(
                trackPoints: exampleTrack.trackPoints,
                parent: anchor
            )

            for object in exampleTrack.objects {
                do {
                    guard let root = try ARMapObjectContent.makeEntity(for: object) else {
                        continue
                    }
                    anchor.addChild(root)
                    if let animation = ARMapObjectContent.animation(
                        for: object,
                        entity: root,
                        phase: Float(animatedObjects.count) * 0.7
                    ) {
                        animatedObjects.append(animation)
                    }
                } catch {
                    print("# EXAMPLE OBJECT LOAD FAILED | \(object.type.name) | \(error)")
                }
            }

            let robotRoot = Entity()
            robotRoot.addChild(model.clone(recursive: true))
            anchor.addChild(robotRoot)
            controller.eduardSimulation.show(entity: robotRoot)
            if !controller.isSimulationVisible {
                controller.toggleSimulationVisibility()
                enabledSimulationVisibility = true
            }
            if let start = ARTrackRenderer().startLinePose(for: exampleTrack.trackPoints) {
                controller.placeSimulationAtStartLine(start)
            }
            controller.eduardSimulation.setVisible(true)

            view.scene.addAnchor(anchor)
            coinRenderer.update(
                coins: exampleTrack.coins,
                parent: anchor,
                mapAnchor: anchor,
                arView: view
            )
            animationSubscription = view.scene.subscribe(to: SceneEvents.Update.self) {
                [weak self] event in
                guard let self else { return }
                self.animationTime += Float(event.deltaTime)
                ARMapObjectContent.animate(self.animatedObjects, at: self.animationTime)
            }

            floorAnchor = anchor
            isPlaced.wrappedValue = true
        }

        func cleanUp() {
            controller.eduardSimulation.stop()
            controller.eduardSimulation.hide()
            if enabledSimulationVisibility && controller.isSimulationVisible {
                controller.toggleSimulationVisibility()
            }
            enabledSimulationVisibility = false
            animationSubscription?.cancel()
            animationSubscription = nil
            animatedObjects.removeAll()
            coinRenderer.clear()
            floorAnchor?.removeFromParent()
            floorAnchor = nil
            arView?.session.delegate = nil
            arView = nil
        }
    }
}
