//
//  SettingsView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI

struct SettingsView: View {

    var body: some View {

        ZStack {

            Color.black
                .ignoresSafeArea()

            VStack(
                alignment:
                    .leading,

                spacing:
                    18
            ) {

                Text(
                    "Settings"
                )
                .font(
                    .largeTitle.bold()
                )
                .foregroundStyle(
                    .white
                )

                Spacer()
            }
            .padding(
                30
            )
        }
    }
}


struct ScoresView: View {

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
                                        )
                                )
                            }
                        }
                    }
                }
                .padding(
                    24
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

        SettingsView()
    }
}
