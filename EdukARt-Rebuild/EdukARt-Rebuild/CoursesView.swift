//
//  CoursesView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI

struct CoursesView: View {

    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var gameMapStore: GameMapStore

    @StateObject private var mapBuilder = AprilTagMapBuilder()

    var body: some View {
        MapMenuBackground {
            VStack(spacing: 20) {
                MapMenuPanel {
                    Text("Courses")
                        .mapMenuTitleStyle()

                    NavigationLink {
                        CreateMapView(
                            eduardModelStore: eduardModelStore,
                            mapBuilder: mapBuilder,
                            gameMapStore: gameMapStore
                        )
                    } label: {
                        Text("Create Map")
                    }
                    .buttonStyle(MapMenuButtonStyle(color: Color("BrandGreen")))

                    Text("Saved Maps")
                        .font(.headline)
                        .foregroundStyle(.white)

                    SavedMapsListView(
                        gameMapStore: gameMapStore,
                        showsCourseActions: true
                    )
                }

                Spacer()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    CoursesView(
        eduardModelStore: EduardModelStore(),
        gameMapStore: GameMapStore()
    )
}
