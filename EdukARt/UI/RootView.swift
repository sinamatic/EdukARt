//
//  RootView.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import SwiftUI

struct RootView: View {
    @StateObject private var mapStore = MapStore()
    @State private var phase: LaunchPhase = .logo
    @State private var loadingProgress: Double = 0
    @State private var hasStartedLaunchSequence = false

    var body: some View {
        Group {
            switch phase {
            case .logo:
                logoScreen
            case .loading:
                loadingScreen
            case .menu:
                menuScreen
            case .gameLoading:
                gameLoadingScreen
            case .game:
                GameView {
                    phase = .menu
                }
            case .createMap:
                CreateMapView(mapStore: mapStore) {
                    phase = .menu
                }
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
                    Button("Start Game") {
                        Task {
                            await runGameStartSequence()
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
        phase = .gameLoading

        let steps = 100
        for step in 0...steps {
            loadingProgress = Double(step) / Double(steps)
            try? await Task.sleep(for: .milliseconds(42))
        }

        try? await Task.sleep(for: .milliseconds(900))
        phase = .game
    }
}

private enum LaunchPhase {
    case logo
    case loading
    case menu
    case gameLoading
    case game
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
