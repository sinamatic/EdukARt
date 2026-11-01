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
    var onShowTutorial: () -> Void = {}
    
    
    
    
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
                    RobotRemoteView(controller: controller)}
                label: {Text("Robot Remote")}
                
                    .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay")))

                NavigationLink {

                    ScoresView(
                        eduardModelStore:
                            eduardModelStore,

                        controller:
                            controller,

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
                        color: Color("BlackOverlay")
                    )
                )

                Spacer()
                    .frame(height: 18)

                NavigationLink{
                    ConsumentaCourseAccessView(
                        eduardModelStore: eduardModelStore,
                        controller: controller,
                        gameMapStore: gameMapStore
                    )
                } label: {Text("Courses")}
                    .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay").opacity(0.2)))

                NavigationLink
                {
                    SettingsView(
                        eduardModelStore: eduardModelStore,
                        controller: controller,
                        gameMapStore: gameMapStore
                    )
                } label: {Text("Debugging")}
                    .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay").opacity(0.2)))
                }
            .padding(30)

                }
        .overlay(alignment: .topLeading) {
            Button(action: onShowTutorial) {
                Image(systemName: "questionmark")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(.black.opacity(0.72))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.65), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .accessibilityLabel("Einführung öffnen")
            .padding(.top, 58)
            .padding(.leading, 30)
        }
        .overlay(alignment: .bottom) {
            Text(verbatim: "www.sinamatic.de")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.black.opacity(0.45))
                .clipShape(Capsule())
                .padding(.bottom, 8)
                .allowsHitTesting(false)
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
