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

    init(selectedMap: StoredFloorMap? = nil, onBack: @escaping () -> Void = {}) {
        _game = StateObject(wrappedValue: Game(selectedMap: selectedMap))
        self.onBack = onBack
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                SceneViewContainer(game: game, isDebugEnabled: isDebugEnabled)
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

                    if isLandscape == false {
                        ControlPadView(onInputChanged: game.updateInput)
                    }
                }
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                if isLandscape {
                    ControlPadView(onInputChanged: game.updateInput)
                        .padding(.trailing, 32)
                        .padding(.bottom, 32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
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
