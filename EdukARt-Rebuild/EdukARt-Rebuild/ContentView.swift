//
//  ContentView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI

struct ContentView: View {

    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var robotController = RobotController()


    @State private var showLogo = true

    var body: some View {

        if showLogo {

            Image("EduArtSinamaticIcon")
            
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()
                    // Eduard schon im Hintergrund laden
                .task {

                        // Eduard parallel im Hintergrund laden
                        Task {
                            await eduardModelStore.load()
                        }

                        // Logo mindestens 2 Sekunden anzeigen
                        try? await Task.sleep(
                            for: .seconds(2)
                        )

                        showLogo = false
                    
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
