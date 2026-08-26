//
//  ContentView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI

struct ContentView: View {

    @ObservedObject var eduardModelStore:
        EduardModelStore

    @StateObject private var robotController =
        RobotController()

    @State private var showLogo =
        true


    var body: some View {

        if showLogo {

            Image(
                "EduArtSinamaticIcon"
            )
            .resizable()
            .scaledToFit()
            .ignoresSafeArea()
            .task {

                Task {
                    await eduardModelStore.load()
                }

                try? await Task.sleep(
                    for:
                        .seconds(2)
                )

                showLogo =
                    false
            }

        } else {

            NavigationStack {

                MainMenuView(
                    eduardModelStore:
                        eduardModelStore,

                    controller:
                        robotController
                )
            }
            .ignoresSafeArea()
            .preferredColorScheme(
                .dark
            )
        }
    }
}


#Preview {

    ContentView(
        eduardModelStore:
            EduardModelStore()
    )
}
