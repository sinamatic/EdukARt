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

            Color.black.opacity(EdukARtUI.Opacity.menuOverlay)
                .ignoresSafeArea()

            VStack(spacing: EdukARtUI.Layout.menuOuterSpacing) {
                Spacer()

                VStack(spacing: EdukARtUI.Layout.menuButtonSpacing) {
                    Button("Start Game") {
                        onStartGame()
                    }
                    .buttonStyle(StartScreenButtonStyle(fillColor: EdukARtUI.Colors.brandGreen))

                    Button("Robot Control") {
                        onRobotControl()
                    }
                    .buttonStyle(StartScreenButtonStyle(fillColor: .black.opacity(EdukARtUI.Opacity.primaryMenuButton), foregroundColor: .white))
                }
                .padding(.top, EdukARtUI.Layout.menuTopPadding)

                Spacer()
            }
            .padding(.horizontal, EdukARtUI.Layout.menuHorizontalPadding)
            .padding(.vertical, EdukARtUI.Layout.menuVerticalPadding)
        }
    }
}

struct StartScreenButtonStyle: ButtonStyle {
    let fillColor: Color
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: EdukARtUI.Layout.startButtonFontSize, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, EdukARtUI.Layout.startButtonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: EdukARtUI.Layout.startButtonCornerRadius, style: .continuous)
                    .fill(fillColor)
                    .opacity(configuration.isPressed ? EdukARtUI.Opacity.pressedButton : EdukARtUI.Layout.defaultButtonScale)
            )
            .foregroundStyle(foregroundColor)
            .scaleEffect(configuration.isPressed ? EdukARtUI.Layout.pressedButtonScale : EdukARtUI.Layout.defaultButtonScale)
            .animation(.easeOut(duration: EdukARtUI.Timing.buttonPressAnimationDuration), value: configuration.isPressed)
    }
}
