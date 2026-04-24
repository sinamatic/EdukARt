//
//  GameView.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import SwiftUI

struct GameView: View {
    @StateObject private var world = GameWorld()

    var body: some View {
        ZStack {
            SceneViewContainer(world: world)
                .ignoresSafeArea()

            VStack {
                Spacer()

                ControlPadView(onInputChanged: world.updateInput)
                .padding(.bottom, 40)
            }
        }
    }
}
