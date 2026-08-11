//
//  UILogo.swift
//  EdukARt
//

import SwiftUI

struct UILogo: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Image("EduArtSinamaticIcon")
                .resizable()
                .scaledToFit()
                .frame(width: EdukARtUI.Layout.logoSize, height: EdukARtUI.Layout.logoSize)
        }
    }
}
