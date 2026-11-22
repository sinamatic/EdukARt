import SwiftUI
import UIKit

enum DeviceLayout {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

struct IPadKeyvisualBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Image("Keyvisual")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }
}
