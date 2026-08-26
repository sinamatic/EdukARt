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
    
    
    
    var body: some View {
        
        
        ZStack {
            Image("Keyvisual")
                .resizable()
                .scaledToFill()
                
            
            
            VStack(spacing: 12) {
                
                
                NavigationLink {
                    StartGameView()
                } label: {Text("Start Game")}
                    .buttonStyle(MenuButtonStyle(color: Color("BrandGreen")))
                
                NavigationLink{
                    CoursesView()
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
                    GameView(
                            eduardModelStore:
                                eduardModelStore
                        )

                } label: {
                    Text("AR Test")
                }
                
                .disabled(eduardModelStore.model == nil)
                
                
                
//                NavigationLink {
//                    CameraARView(
//                        
//                        eduardModelStore: eduardModelStore
//                    )
//                    .ignoresSafeArea()
//                } label: {
//                    Text(
//                        eduardModelStore.model == nil
//                            ? "Loading Eduard..."
//                            : "AR Test"
//                    )
//                }
//                .disabled(eduardModelStore.model == nil)
//
//                .onChange(of: eduardModelStore.model == nil) { _, isNil in
//                    print("MENU model is nil:", isNil)
                }
            .padding(30)

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
            eduardModelStore: EduardModelStore()
        )
        
    }
