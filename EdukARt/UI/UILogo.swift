//
//  UILogo.swift
//  EdukARt
//

import SwiftUI

struct UILogo: View {
    private let logoSize: CGFloat = 220
    
    var body: some View {
        ZStack {
            Color.black
            .ignoresSafeArea() // fits background over status row above or beneigh home button,
            
            Image("EduArtSinamaticIcon")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize) // max frame 220x22x pixel without cropping, fits into it
        }
    }
}
