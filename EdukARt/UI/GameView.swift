//
//  GameView.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import SwiftUI

struct GameView: View {
    @StateObject private var game: Game
    @State private var isDebugEnabled = false
    let onBack: () -> Void
    let onCameraReady: () -> Void

    init(
        selectedMap: StoredFloorMap? = nil,
        onCameraReady: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {}
    ) {
        _game = StateObject(wrappedValue: Game(selectedMap: selectedMap))
        self.onCameraReady = onCameraReady
        self.onBack = onBack
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                SceneViewContainer(
                    game: game,
                    isDebugEnabled: isDebugEnabled,
                    onCameraReady: onCameraReady
                )
                    .ignoresSafeArea()

                VStack {
                    HStack {
                        Button("Zurück") {
                            onBack()
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.65))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())

                        Spacer()

                        if let realRobotTagName = game.realRobotTagName {
                            Text("Real \(displayNumber(for: realRobotTagName))")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.green.opacity(0.82))
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }

                        Button(isDebugEnabled ? "Debug On" : "Debug") {
                            isDebugEnabled.toggle()
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.65))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    Spacer()
                }

                VStack(spacing: 12) {
                    statusMessages
                    speedControls
                }
                .padding(.bottom, isLandscape ? 40 : 190)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                RotationPadView(onRotationChanged: game.updateRotationInput)
                    .padding(.leading, isLandscape ? 32 : 28)
                    .padding(.bottom, isLandscape ? 32 : 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                ControlPadView(onInputChanged: game.updateInput)
                    .padding(.trailing, isLandscape ? 32 : 28)
                    .padding(.bottom, isLandscape ? 32 : 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }

    private var speedControls: some View {
        HStack(spacing: 8) {
            ForEach(Game.SpeedMode.allCases) { mode in
                Button(mode.rawValue) {
                    game.speedMode = mode
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(game.speedMode == mode ? .yellow.opacity(0.9) : .black.opacity(0.65))
                .foregroundStyle(game.speedMode == mode ? .black : .white)
                .clipShape(Capsule())
            }
        }
    }

    private var statusMessages: some View {
        VStack(spacing: 12) {
            if let itemBoxMessage = game.itemBoxMessage {
                Text(itemBoxMessage)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.yellow.opacity(0.9))
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }

            if let mapOriginMessage = game.mapOriginMessage {
                Text(mapOriginMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.72))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24)
            }

            if let collisionMessage = game.collisionMessage {
                Text(collisionMessage)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.red.opacity(0.85))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }

    private func displayNumber(for tagName: String) -> String {
        let trailingDigits = tagName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .reversed()
            .prefix(while: { $0.isNumber })
            .reversed()

        guard trailingDigits.isEmpty == false else {
            return tagName
        }

        return "#\(String(trailingDigits))"
    }
}
