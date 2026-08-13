//
//  RootView.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import SwiftUI

struct RootView: View {
    
    @StateObject private var robotController = RobotController()
    @StateObject private var mapStore = MapStore()
    
    @State private var phase: AppPhase = .logo
    @State private var selectedMap: GameMap?
    
    var body: some View {
        Group {
            if phase == .logo {
                UILogo()
            } else {
                GeometryReader { geometry in
                    if phase == .menu {
                        ZStack(alignment: .top) {
                            currentView
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity
                                )
                                .ignoresSafeArea()
                            
                            topBar(
                                safeAreaTop: geometry.safeAreaInsets.top,
                                showsBackground: false
                            )
                        }
                        .background(.black)
                        .ignoresSafeArea(edges: .top)
                    } else {
                        VStack(spacing: 0) {
                            topBar(
                                safeAreaTop: geometry.safeAreaInsets.top,
                                showsBackground: true
                            )
                            
                            currentView
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .top
                                )
                                .clipped()
                        }
                        .background(.black)
                        .ignoresSafeArea(edges: .top)
                    }
                }
            }
        }
        .task {
            await leaveLogoAfterDelay()
        }
    }
    
    
    private func topBar(
        safeAreaTop: CGFloat,
        showsBackground: Bool
    ) -> some View {
        UITopBar(
            onBack: backAction,
            controller: robotController,
            showsBackground: showsBackground
        )
        .padding(.top, safeAreaTop)
        .frame(
            height: safeAreaTop + UIGlobals.topBarHeight,
            alignment: .bottom
        )
        .background(showsBackground ? .black : .clear)
    }
    
    
    @ViewBuilder
    private var currentView: some View {
        
        switch phase {
            
        case .logo:
            EmptyView()
            
            
        case .menu:
            UIMenuMain(
                onStartGame: {
                    phase = .selectMap
                },
                onRobotControl: {
                    phase = .remoteControl
                }
            )
            
            
        case .remoteControl:
            UIRobotControl(
                controller: robotController
            )
            
            
        case .selectMap:
            UIStartGameChooseMap(
                mapStore: mapStore,
                onCreateMap: {
                    phase = .createMap
                },
                onSelectMap: { map in
                    selectedMap = map
                    phase = .game
                }
            )
            
            
        case .createMap:
            UICreateMap(
                mapStore: mapStore
            )
            
            
        case .game:
            UIGameView(
                onBack: {
                    phase = .selectMap
                }
            )
        }
    }
    
    
    private var backAction: (() -> Void)? {
        
        switch phase {
            
        case .logo, .menu:
            return nil
            
        case .remoteControl:
            return {
                phase = .menu
            }
            
        case .selectMap:
            return {
                phase = .menu
            }
            
        case .createMap:
            return {
                phase = .selectMap
            }
            
        case .game:
            return {
                phase = .selectMap
            }
        }
    }
    
    
    @MainActor
    private func leaveLogoAfterDelay() async {
        guard phase == .logo else {
            return
        }
        
        try? await Task.sleep(for: .seconds(1))
        
        if phase == .logo {
            phase = .menu
        }
    }
    
    
    private enum AppPhase {
        case logo
        case menu
        case remoteControl
        case selectMap
        case createMap
        case game
    }
}
