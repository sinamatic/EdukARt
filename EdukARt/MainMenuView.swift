//
//  MainMenuView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI

struct MainMenuView: View {
    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var controller: RobotController
    @ObservedObject var gameMapStore: GameMapStore
    
    
    
    
    var body: some View {
        
        
        ZStack {
            Image("Keyvisual")
                .resizable()
                .scaledToFill()
                
            
            
            VStack(spacing: 12) {
                
                
                NavigationLink {
                    StartGameView(
                        eduardModelStore: eduardModelStore,
                        controller: controller,
                        gameMapStore: gameMapStore
                    )
                } label: {Text("Start Game")}
                    .buttonStyle(MenuButtonStyle(color: Color("BrandGreen")))
                
                NavigationLink{
                    CoursesView(
                        eduardModelStore: eduardModelStore,
                        controller: controller,
                        gameMapStore: gameMapStore
                    )
                } label: {Text("Courses")}
                    .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay")))
                
                NavigationLink{
                    RobotRemoteView(controller: controller)}
                label: {Text("Robot Remote")}
                
                    .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay")))
                
                NavigationLink
                {
                    SettingsView()
                } label: {Text("Settings")}
                    .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay")))

                NavigationLink {

                    ScoresView(
                        gameMapStore:
                            gameMapStore
                    )

                } label: {

                    Text(
                        "Scores"
                    )
                }
                .buttonStyle(
                    MenuButtonStyle(
                        color:
                            Color(
                                "BlackOverlay"
                            )
                            .opacity(
                                0.72
                            )
                    )
                )
                .padding(
                    .top,
                    18
                )
                }
            .padding(30)

                }
        .onAppear {

            controller.resetForManualControl()
        }
        
                

                }
        
        
//        .onAppear {
//            PerformanceLogger.shared.end("App to Main Menu")
//        }
        
        
    }
    
    
    private struct MenuButtonStyle: ButtonStyle {
        let color: Color
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .padding()
                .background(color)
                .clipShape(
                    RoundedRectangle(cornerRadius: 18)
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(
                    
                    .easeOut(duration: 0.12),
                    value: configuration.isPressed
                )
        }
    }
    
    
    
    
    
    #Preview {
        MainMenuView(
            eduardModelStore:
                EduardModelStore(),

            controller:
                RobotController(),
            
            gameMapStore:
                GameMapStore()
            
        )
        
    }
