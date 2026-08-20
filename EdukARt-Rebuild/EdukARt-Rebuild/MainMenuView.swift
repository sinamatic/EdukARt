//
//  MainMenuView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI

struct MainMenuView: View {
    var body: some View {
        
        ZStack {
            Image("Keyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            
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
                    RobotRemoteView() }
                label: {Text("Robot Remote")}
                
                    .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay")))
                
                NavigationLink
                {
                    SettingsView()
                } label: {Text("Settings")}
                    .buttonStyle(MenuButtonStyle(color: Color("BlackOverlay")))
            }
            .padding(30)
            
        }
        
        
        
        
        
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
}
    
    
    
    
    
    #Preview {
        MainMenuView()
    }
