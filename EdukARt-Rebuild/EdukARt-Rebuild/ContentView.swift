//
//  ContentView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI

struct ContentView: View {

    var body: some View {
            NavigationStack {
                MainMenuView()
                    .preferredColorScheme(.dark)
            }
        }
    }

#Preview {
    ContentView()
}
