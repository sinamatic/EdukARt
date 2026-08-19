//
//  RootView.swift
//  EdukARt
//
//  Created by Sina Steinmüller on 21.04.26.
//

import SwiftUI

struct RootView: View {
    
    @StateObject private var robotController = RobotController()
    @StateObject private var simulatedRobotController = SimulatedRobotController()
    
    @StateObject private var mapStore = MapStore()
    
    @State private var phase: AppPhase = .logo
    @State private var selectedMap: GameMap?
    @State private var editingTrackPoints: [MapPoint] = []
    @State private var editingTrackElements: [MapTrackElement] = []
    
    
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
        .onAppear {
            configureRobotTransport()
        }
        .onChange(of: robotController.usedRobot) {
            configureRobotTransport()
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
                    configureRobotTransport()
                    phase = .localizeMap
                },
                onEditTrack: { map in
                    selectedMap = map
                    editingTrackPoints = map.trackPoints
                    editingTrackElements = map.trackElements
                    phase = .editTrack
                }
            )
            
            
        case .createMap:
            UICreateMap(
                mapStore: mapStore
            )
        
        case .localizeMap:
            if let selectedMap {
                
                UIMapLocalization(
                    map: selectedMap,
                    onBack: {
                        phase = .selectMap
                    },
                    controller: robotController,
                    simulatedRobot: simulatedRobotController
                    
                    
                )
            
            }
            
            
        case .editTrack:
            if let selectedMap {
                UITrackEditor(
                    map: selectedMap,
                    trackPoints: $editingTrackPoints,
                    trackElements: $editingTrackElements,
                    onSave: {
                        saveEditedTrack()
                    }
                )
            }
            
            
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
            
        case .localizeMap:
            return {
                phase = .selectMap
            }
            
        case .editTrack:
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
        case localizeMap
        case editTrack
        case game
       
    }
    
    
    private func saveEditedTrack() {
        guard var selectedMap else {
            phase = .selectMap
            return
        }
        
        selectedMap.trackPoints = editingTrackPoints
        selectedMap.trackElements = editingTrackElements
        
        try? mapStore.update(selectedMap)
        
        self.selectedMap = selectedMap
        phase = .selectMap
    }


    private func configureRobotTransport() {
        switch robotController.usedRobot {
        case .eduard:
            robotController.setCommandTransport(
                robotController.eduardCommandTransport
            )

        case .simulation:
            robotController.setCommandTransport(
                SimulationCommandTransport(
                    simulatedRobot: simulatedRobotController
                )
            )
        }
    }
}
