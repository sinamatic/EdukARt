import SwiftUI
import SwiftUIJoystick

struct GameARMenu: View {
    @Binding var isOpen: Bool
    let isSimulationVisible: Bool
    let isLiveSyncEnabled: Bool
    let canPlaceOnStart: Bool
    let canShowAR: Bool
    let isExample: Bool
    let topInset: CGFloat
    let onPlaceOnStart: () -> Void
    let onSync: () -> Void
    let onToggleLiveSync: () -> Void
    let onToggleAR: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isOpen.toggle()
                }
            } label: {
                Image(systemName: "arkit")
                    .font(.title3.weight(.bold))
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("AR Menu")
            }
            .buttonStyle(RobotStatusIconButtonStyle(isEnabled: isOpen))
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.36), lineWidth: 2)
                    .allowsHitTesting(false)
            }

            if isOpen {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: onPlaceOnStart) {
                        row(icon: "scope", title: "Place on Start")
                    }
                    .disabled(!canPlaceOnStart)

                    Button(action: onSync) {
                        row(icon: "arrow.triangle.2.circlepath", title: "Sync")
                    }
                    .disabled(isExample)

                    Button(action: onToggleLiveSync) {
                        row(
                            icon: "dot.radiowaves.left.and.right",
                            title: "Live Sync",
                            statusIcon: isLiveSyncEnabled ? "checkmark.circle.fill" : "xmark.circle.fill",
                            statusColor: isLiveSyncEnabled ? .green : .red
                        )
                    }
                    .disabled(isExample)

                    Button(action: onToggleAR) {
                        row(
                            icon: isSimulationVisible ? "eye.slash" : "arkit",
                            title: isSimulationVisible ? "Hide AR" : "Show AR"
                        )
                    }
                    .disabled(!canShowAR)

                    if isExample {
                        Text("Sync and Live Sync require AprilTags")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(.black.opacity(0.68))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .buttonStyle(.plain)
        .padding(.top, topInset)
        .padding(.leading, 21)
    }

    private func row(
        icon: String,
        title: String,
        statusIcon: String? = nil,
        statusColor: Color = .white
    ) -> some View {
        HStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .frame(width: 28, height: 22)
                if let statusIcon {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                        .font(.caption2)
                        .offset(x: 8, y: -4)
                }
            }
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(width: 124, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct GameMinimapPanel: View {
    let map: GameMap?
    let robotPose: RobotPose?
    let simulationPose: RobotPose?
    let runtimeMapObjects: [PlacedMapObject]?
    let shitDots: [ShitDot]
    let isLocalized: Bool
    let coinCount: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if let map {
                StoredGameMapView(
                    map: map,
                    robotPose: robotPose,
                    simulationPose: simulationPose,
                    runtimeMapObjects: runtimeMapObjects,
                    shitDots: shitDots
                )
                .frame(width: isLocalized ? 180 : 360, height: isLocalized ? 180 : 360)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.black.opacity(0.5))
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.7), lineWidth: 1)
                    Text("No AprilTags")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                .frame(width: 180, height: 180)
            }

            if let coinCount {
                Text(coinCount)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.55))
                    .clipShape(Capsule())
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: isLocalized ? .topTrailing : .bottom
        )
        .padding(.top, isLocalized ? 20 : 0)
        .padding(.trailing, isLocalized ? 20 : 0)
        .padding(.bottom, isLocalized ? 0 : 40)
        .animation(.easeInOut(duration: 0.45), value: isLocalized)
        .allowsHitTesting(false)
    }
}


struct GameJoystickControls: View {
    @ObservedObject var joystickMonitor: JoystickMonitor
    @ObservedObject var turnJoystickMonitor: JoystickMonitor
    let controller: RobotController
    let isEnabled: Bool

    var body: some View {
        JoystickView(
            joystickMonitor: joystickMonitor,
            turnJoystickMonitor: turnJoystickMonitor,
            width: 180,
            shape: .circle,
            spreadsControls: DeviceLayout.isPad
        )
        .frame(maxWidth: .infinity)
        .onChange(of: joystickMonitor.xyPoint) { _, point in
            guard isEnabled else { return }
            updateTranslation(point)
        }
        .onChange(of: turnJoystickMonitor.xyPoint) { _, point in
            guard isEnabled else { return }
            updateRotation(point)
        }
        .onDisappear {
            controller.stopJoystick()
            controller.stopMechanumRotation()
        }
    }

    private func updateTranslation(_ point: CGPoint) {
        let x: Float = Float(point.x) / 180
        let y: Float = Float(point.y) / 180
        controller.updateJoystickInput(x: x, y: y)
    }

    private func updateRotation(_ point: CGPoint) {
        let x: Float = Float(point.x) / 120
        controller.updateMechanumRotationInput(x: x)
    }
}

struct GameStatusBar: View {
    let timeText: String?
    let speedPercent: Int
    let damageCount: Int?

    var body: some View {
        HStack(spacing: 8) {
            if let timeText {
                Text(timeText)
                    .font(.headline.monospacedDigit())
            }
            Text("Speed \(speedPercent)%")
                .font(.caption.bold())
            if let damageCount {
                Text("Damage \(damageCount)")
                    .font(.caption.bold())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.62))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 28)
        .offset(y: -50)
        .allowsHitTesting(false)
    }
}
