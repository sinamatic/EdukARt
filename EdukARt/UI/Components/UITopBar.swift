//
//  UITopBar.swift
//  EdukARt
//

import SwiftUI

struct UITopBar: View {
    
    let onBack: (() -> Void)?
    @ObservedObject var controller: RobotController
    var showsBackground = true
    
    var body: some View {
        HStack {
            
            if let onBack {
                Button("Back") {
                    onBack()
                }
            }
            
            Spacer()
            
            UIRobotStatusOverlay(
                controller: controller
            )
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .frame(height: UIGlobals.topBarHeight)
        .background(showsBackground ? .black : .clear)
    }
}
