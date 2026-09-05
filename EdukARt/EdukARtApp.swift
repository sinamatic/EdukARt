//
//  EdukARt_RebuildApp.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI

@main
struct EdukARtApp: App {
    
    @StateObject private var eduardModelStore = EduardModelStore()
    
    init() {
            PerformanceLogger.shared.start("App to Main Menu")
        }
    
    var body: some Scene {
        
        
        
        
        WindowGroup {
            ContentView(
                eduardModelStore: eduardModelStore
            )
            
        }
    }
}
