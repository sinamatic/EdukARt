//
//  SettingsView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI

struct SettingsView: View {

    @AppStorage("showLocalizationBypassButton")
    private var showLocalizationBypassButton = false

    @ObservedObject var eduardModelStore:
        EduardModelStore

    @ObservedObject var controller:
        RobotController

    @ObservedObject var gameMapStore:
        GameMapStore


    var body: some View {

        ZStack {

            Color.black
                .ignoresSafeArea()

            ScrollView {
                VStack(
                alignment:
                    .leading,

                spacing:
                    18
            ) {

                Text(
                    "Debugging"
                )
                .font(
                    .largeTitle.bold()
                )
                .foregroundStyle(
                    .white
                )

                Text(
                    "Use this if the physical Eduard keeps an old drive state after a game. It stops gameplay effects and sends a fresh disable/enable reset to the robot."
                )
                .font(
                    .callout
                )
                .foregroundStyle(
                    .white.opacity(
                        0.72
                    )
                )

                Button {

                    controller.resetPhysicalRobot()

                } label: {

                    Label(
                        "Reset Robot Drive",
                        systemImage:
                            "arrow.triangle.2.circlepath"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    SettingsMenuButtonStyle()
                )

                Toggle(
                    "Show “Weiter ohne Lokalisierung”",
                    isOn: $showLocalizationBypassButton
                )
                .font(.headline)
                .foregroundStyle(.white)
                .tint(Color("BrandGreen"))
                .padding()
                .background(Color.white.opacity(0.08))
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                )

                VStack(
                    alignment:
                        .leading,

                    spacing:
                        6
                ) {
                    Text(
                        "AR Coordinate Systems"
                    )
                    .font(
                        .title3.bold()
                    )
                    .foregroundStyle(
                        .white
                    )

                    Text(
                        "Open these views to debug and understand the coordinate systems behind EdukARt's AR mapping."
                    )
                    .font(
                        .callout
                    )
                    .foregroundStyle(
                        .white.opacity(
                            0.72
                        )
                    )
                }
                .padding(
                    .top,
                    8
                )

                NavigationLink {
                    ShowARkitCoordinateSystem()
                } label: {
                    Label(
                        "Show ARkit World Coordinate System",
                        systemImage:
                            "arkit"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    SettingsMenuButtonStyle()
                )

                NavigationLink {
                    ShowAprilTagCoordinateSystem()
                } label: {
                    Label(
                        "Show AprilTag Coordinate System",
                        systemImage:
                            "viewfinder"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    SettingsMenuButtonStyle()
                )

                NavigationLink {
                    ShowEdukARtMapCoordinateSystem()
                } label: {
                    Label(
                        "Show EdukARt Map Coordinate System",
                        systemImage:
                            "map"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    SettingsMenuButtonStyle()
                )

                NavigationLink {
                    ShowFloorMiniMapCoordinateSystem()
                } label: {
                    Label(
                        "Show Floor MiniMap",
                        systemImage:
                            "grid"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    SettingsMenuButtonStyle()
                )

                if UIDevice.current.userInterfaceIdiom == .pad {
                    NavigationLink {
                        SpectatorGhostLibraryView(
                            eduardModelStore: eduardModelStore,
                            controller: controller,
                            gameMapStore: gameMapStore
                        )
                    } label: {
                        Label(
                            "Start Spectator Mode",
                            systemImage: "rectangle.inset.filled.and.person.filled"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SettingsMenuButtonStyle())
                    .padding(.top, 8)
                }

                Text(
                    controller.statusMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .white.opacity(
                        0.64
                    )
                )

                Spacer()
            }
                .padding(
                    30
                )
            }
        }
    }
}


struct ScoresView: View {

    @ObservedObject var eduardModelStore:
        EduardModelStore

    @ObservedObject var controller:
        RobotController

    @ObservedObject var gameMapStore:
        GameMapStore

    @State private var selectedGhostMap:
        GameMap?

    @State private var selectedGhostURL:
        URL?

    var body: some View {

        ZStack {

            Color.black
                .ignoresSafeArea()

            ScrollView {

                VStack(
                    alignment:
                        .leading,

                    spacing:
                        18
                ) {

                    Text(
                        "Scores"
                    )
                    .font(
                        .largeTitle.bold()
                    )
                    .foregroundStyle(
                        .white
                    )

                    if gameMapStore.maps.isEmpty {

                        Text(
                            "No maps available"
                        )
                        .foregroundStyle(
                            .white.opacity(
                                0.7
                            )
                        )

                    } else {

                        ForEach(
                            gameMapStore.maps
                        ) { map in

                            VStack(
                                alignment:
                                    .leading,

                                spacing:
                                    10
                            ) {

                                Text(
                                    map.name
                                )
                                .font(
                                    .headline
                                )
                                .foregroundStyle(
                                    .white
                                )

                                LeaderboardResultsView(
                                    results:
                                        leaderboardResults(
                                            for:
                                                map
                                        ),

                                    onGhostSelected: { result in
                                        guard let url = GameController.ghostRecordingURL(
                                            for: result
                                        ) else {
                                            return
                                        }

                                        selectedGhostMap = map
                                        selectedGhostURL = url
                                    },

                                    ghostURLProvider: { result in
                                        GameController.ghostRecordingURL(
                                            for: result
                                        )
                                    }
                                )
                            }
                        }
                    }
                }
                .frame(
                    maxWidth:
                        .infinity,

                    alignment:
                        .leading
                )
                .padding(
                    .horizontal,
                    20
                )
                .padding(
                    .vertical,
                    24
                )
            }
        }
        .navigationDestination(
            isPresented: Binding(
                get: {
                    selectedGhostMap != nil
                        && selectedGhostURL != nil
                },
                set: { isPresented in
                    if isPresented == false {
                        selectedGhostMap = nil
                        selectedGhostURL = nil
                    }
                }
            )
        ) {
            if let selectedGhostMap,
               let selectedGhostURL {
                GameView(
                    map: selectedGhostMap,
                    eduardModelStore: eduardModelStore,
                    controller: controller,
                    initialGhostRecordingURL: selectedGhostURL
                )
            }
        }
    }


    private func leaderboardResults(
        for map:
            GameMap
    ) -> [GameResult] {

        let key =
            "leaderboard-\(map.id.uuidString)"

        guard let data =
            UserDefaults.standard.data(
                forKey:
                    key
            ),
              let results =
                try? JSONDecoder()
                    .decode(
                        [GameResult].self,
                        from:
                            data
                    )
        else {
            return []
        }

        return results.sorted {
            $0.elapsedTime < $1.elapsedTime
        }
    }
}


private struct SettingsMenuButtonStyle: ButtonStyle {

    func makeBody(
        configuration:
            Configuration
    ) -> some View {

        configuration.label
            .font(
                .headline
            )
            .frame(
                maxWidth:
                    .infinity
            )
            .foregroundStyle(
                .white
            )
            .padding()
            .background(
                Color(
                    "BrandGreen"
                )
                .opacity(
                    0.5
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        18
                )
            )
            .scaleEffect(
                configuration.isPressed
                ? 0.95
                : 1.0
            )
            .animation(
                .easeOut(
                    duration:
                        0.12
                ),
                value:
                    configuration.isPressed
            )
    }
}


#Preview {

    NavigationStack {

        SettingsView(
            eduardModelStore: EduardModelStore(),
            controller: RobotController(),
            gameMapStore: GameMapStore()
        )
    }
}
