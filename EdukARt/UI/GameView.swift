//
//  GameView.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import SwiftUI

struct GameView: View {
    @StateObject private var game = Game()
    @State private var isDebugEnabled = false
    let onBack: () -> Void

    init(onBack: @escaping () -> Void = {}) {
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            SceneViewContainer(game: game, isDebugEnabled: isDebugEnabled)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button("Zurück") {
                        onBack()
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.65))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())

                    Spacer()

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
                .padding(.horizontal, 20)
                .padding(.top, 14)

                Spacer()

                VStack(spacing: 16) {
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

                    ControlPadView(onInputChanged: game.updateInput)
                        .padding(.bottom, 40)
                }
            }
        }
    }
}
