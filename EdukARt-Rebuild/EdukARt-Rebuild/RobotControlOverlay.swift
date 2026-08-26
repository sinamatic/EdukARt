//
//  RobotControlOverlay.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 26.08.26.
//

import SwiftUI


struct RobotControlOverlay: View {

    @ObservedObject var controller:
        RobotController


    var body: some View {

        Button {

            controller.toggleEnabled()

        } label: {

            HStack(
                spacing: 8
            ) {

                Circle()
                    .fill(
                        controller.isEnabled
                        ? Color.green
                        : Color.red
                    )
                    .frame(
                        width: 10,
                        height: 10
                    )


                Text(
                    controller.isEnabled
                    ? "Disable"
                    : "Enable"
                )
                .fontWeight(
                    .semibold
                )
            }
            .padding(
                .horizontal,
                14
            )
            .padding(
                .vertical,
                10
            )
            .background(
                .black.opacity(0.7)
            )
            .clipShape(
                Capsule()
            )
        }
        .buttonStyle(
            .plain
        )
        .foregroundStyle(
            .white
        )
        .frame(
            maxWidth:
                .infinity,

            maxHeight:
                .infinity,

            alignment:
                .topTrailing
        )
        .padding(
            20
        )
    }
}
