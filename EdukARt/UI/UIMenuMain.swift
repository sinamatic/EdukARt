//
//  UIMenuMain.swift
//  EdukARt
//

import SwiftUI

struct UIMenuMain: View {
    
    let onStartGame: () -> Void
    let onRobotControl: () -> Void
    
    var body: some View {
        ZStack {
            
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            Color.black
                .opacity(0.66)
                .ignoresSafeArea()
            
            VStack(spacing: 14) {
                Spacer()
                
                Button("Start Game") {
                    onStartGame()
                }
                .buttonStyle(
                    MainMenuButtonStyle(
                        backgroundColor: UIGlobals.brandGreen
                    )
                )
                
                Button("Robot Control") {
                    onRobotControl()
                }
                .buttonStyle(
                    MainMenuButtonStyle(
                        backgroundColor: .black.opacity(0.62)
                    )
                )
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 40)
        }
    }
}


private struct MainMenuButtonStyle: ButtonStyle {
    
    let backgroundColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(backgroundColor)
                    .opacity(configuration.isPressed ? 0.82 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(
                .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}
