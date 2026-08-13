//
//  UIColorPicker.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 13.08.26.
//

import SwiftUI

struct UIColorPicker: View {
    
    let title: String
    @Binding var color: Color
    
    var body: some View {
        ColorPicker(title, selection: $color)
    }
}
