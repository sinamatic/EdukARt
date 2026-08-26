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
    
    @StateObject private var gameMapStore =
        GameMapStore()

    @State private var showLogo = true


    var body: some View {

        ZStack {
        if showLogo {

            Image(
                "EduArtSinamaticIcon"
            )
            .resizable()
            .scaledToFit()
            .scaleEffect(0.6)
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
                            robotController,
                        
                        gameMapStore:
                            gameMapStore
                        
                    )
                }
                .ignoresSafeArea()
                .preferredColorScheme(
                    .dark
                )
            }
            
            if showLogo == false {
                RobotControlOverlay(
                               controller:
                                   robotController
                           )
                       }
                
                
        }
    }
}


#Preview {

    ContentView(
        eduardModelStore:
            EduardModelStore()
    )
}
