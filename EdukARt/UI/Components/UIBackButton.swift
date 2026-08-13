//
//  BackButton.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 13.08.26.
//

import SwiftUI

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button("Back") {
            action()
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.12))
        .foregroundStyle(.white)
        .clipShape(Capsule())
    }
}
