//
//  StartGameView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI

struct StartGameView: View {

    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var gameMapStore: GameMapStore

    @StateObject private var mapBuilder = AprilTagMapBuilder()

    var body: some View {

        ZStack {

            Image("Keyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black
                .opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {

                NavigationLink {
                    CreateMapView(
                        eduardModelStore: eduardModelStore,
                        mapBuilder: mapBuilder,
                        gameMapStore: gameMapStore
                    )
                } label: {
                    Text("Create Map")
                }
                .buttonStyle(StartGameButtonStyle(color: Color("BrandGreen")))

                VStack(alignment: .leading, spacing: 12) {

                    Text("Saved Maps")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if gameMapStore.maps.isEmpty {

                        Text("No saved maps yet")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color("BlackOverlay"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                    } else {

                        List {
                            ForEach(gameMapStore.maps) { map in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(map.name)
                                        .font(.headline)

                                    Text("Reference Tag #\(map.referenceTagID) | \(map.aprilTags.count) AprilTags")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    gameMapStore.delete(gameMapStore.maps[index])
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                }
                .frame(maxHeight: 360)
            }
            .padding(30)
        }
        .navigationTitle("Start Game")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StartGameButtonStyle: ButtonStyle {

    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .padding()
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    StartGameView(
        eduardModelStore: EduardModelStore(),
        gameMapStore: GameMapStore()
    )
}
