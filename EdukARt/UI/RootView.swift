//
//  RootView.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import SwiftUI

struct RootView: View {
    @StateObject private var mapStore = MapStore()
    @StateObject private var robotRemoteController = RobotRemoteController()
    @State private var phase: LaunchPhase = .logo
    @State private var loadingProgress: Double = 0
    @State private var hasStartedLaunchSequence = false
    @State private var selectedGameMap: StoredFloorMap?
    @State private var isGameCameraReady = false

    var body: some View {
        Group {
            switch phase {
            case .logo:
                logoScreen
            case .loading:
                loadingScreen
            case .menu:
                menuScreen
            case .remoteControl:
                RobotRemoteControlScreen(controller: robotRemoteController) {
                    robotRemoteController.disconnect()
                    phase = .menu
                }
            case .gameLoading:
                gameLoadingScreen
            case .game:
                ZStack {
                    GameView(
                        selectedMap: selectedGameMap,
                        onCameraReady: {
                            isGameCameraReady = true
                        }
                    ) {
                        isGameCameraReady = false
                        phase = .menu
                    }

                    if isGameCameraReady == false {
                        gameLoadingScreen
                    }
                }
            case .selectGameMap:
                gameMapSelectionScreen
            case .createMap:
                CreateMapView(
                    mapStore: mapStore,
                    onClose: {
                        phase = .menu
                    },
                    onStartGame: { map in
                        selectedGameMap = map
                        Task {
                            await runGameStartSequence()
                        }
                    }
                )
            case .viewMaps:
                MapsView(mapStore: mapStore) {
                    phase = .menu
                }
            }
        }
        .task {
            guard hasStartedLaunchSequence == false else {
                return
            }

            hasStartedLaunchSequence = true
            await runLaunchSequence()
        }
    }

    private var logoScreen: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Image("EduArtSinamaticIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
        }
    }

    private var loadingScreen: some View {
        ZStack {
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.22)
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 14) {
                    Text("Loading \(Int(loadingProgress * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    ProgressView(value: loadingProgress)
                        .tint(.white)
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .background(.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 28)
                .padding(.bottom, 56)
            }
        }
    }

    private var gameLoadingScreen: some View {
        ZStack {
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 14) {
                    Text("Starting Game \(Int(loadingProgress * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    ProgressView(value: loadingProgress)
                        .tint(brandGreen)
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .background(.black.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 28)
                .padding(.bottom, 56)
            }
        }
    }

    private var menuScreen: some View {
        ZStack {
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.66)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 14) {
                    Button("Remote Control Robot") {
                        phase = .remoteControl
                    }
                    .buttonStyle(StartScreenButtonStyle(fillColor: .black.opacity(0.62), foregroundColor: .white))

                    Button("Start Game") {
                        if mapStore.maps.isEmpty {
                            selectedGameMap = nil
                            Task {
                                await runGameStartSequence()
                            }
                        } else {
                            phase = .selectGameMap
                        }
                    }
                    .buttonStyle(StartScreenButtonStyle(fillColor: brandGreen))

                    Button("Create Map") {
                        phase = .createMap
                    }
                    .buttonStyle(StartScreenButtonStyle(fillColor: Color.white.opacity(0.82), foregroundColor: brandGreen))

                    Button("View Maps") {
                        phase = .viewMaps
                    }
                    .buttonStyle(StartScreenButtonStyle(fillColor: .black.opacity(0.42), foregroundColor: .white))
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 40)
        }
    }

    private var gameMapSelectionScreen: some View {
        ZStack {
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.84)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Button("Zurueck") {
                        phase = .menu
                    }
                    .buttonStyle(CompactOverlayButtonStyle())

                    Spacer()
                }

                Text("Karte fuer Spiel waehlen")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text("Die Coins werden im Raster auf der gespeicherten Bodenflaeche platziert.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.82))

                List {
                    Button {
                        selectedGameMap = nil
                        Task {
                            await runGameStartSequence()
                        }
                    } label: {
                        Text("Ohne Karte starten")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    ForEach(mapStore.maps) { map in
                        Button {
                            selectedGameMap = map
                            Task {
                                await runGameStartSequence()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(map.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Text("\(map.floorTiles.count) Bodenkacheln")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(brandGreen)

                                Text("AprilTag \(map.displayReferenceTagNumber)")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)
            .padding(.bottom, 24)
        }
    }

    private var brandGreen: Color {
        Color(red: 12.0 / 255.0, green: 117.0 / 255.0, blue: 0)
    }

    @MainActor
    private func runLaunchSequence() async {
        try? await Task.sleep(for: .seconds(3))
        phase = .loading

        let steps = 100
        for step in 0...steps {
            loadingProgress = Double(step) / Double(steps)
            try? await Task.sleep(for: .milliseconds(30))
        }

        phase = .menu
    }

    @MainActor
    private func runGameStartSequence() async {
        loadingProgress = 0
        isGameCameraReady = false
        phase = .gameLoading

        let steps = 100
        for step in 0...steps {
            loadingProgress = Double(step) / Double(steps)
            try? await Task.sleep(for: .milliseconds(42))
        }

        phase = .game
        try? await Task.sleep(for: .seconds(1))
        if isGameCameraReady == false {
            isGameCameraReady = true
        }
    }
}

private enum LaunchPhase {
    case logo
    case loading
    case menu
    case remoteControl
    case gameLoading
    case game
    case selectGameMap
    case createMap
    case viewMaps
}

private struct StartScreenButtonStyle: ButtonStyle {
    let fillColor: Color
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fillColor)
                    .opacity(configuration.isPressed ? 0.82 : 1)
            )
            .foregroundStyle(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct CompactOverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(configuration.isPressed ? 0.48 : 0.65))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}

