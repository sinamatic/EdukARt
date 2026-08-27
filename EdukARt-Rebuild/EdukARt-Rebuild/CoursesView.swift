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

    @State private var editingMap: GameMap?
    @State private var editedMapName = ""
    @State private var showsEditDialog = false

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
                        Text("Create Course")
                    }
                    .buttonStyle(MapMenuButtonStyle(color: Color("BrandGreen")))

                    Text("Saved Maps")
                        .font(.headline)
                        .foregroundStyle(.white)

                    SavedMapsListView(
                        gameMapStore: gameMapStore,
                        showsCourseActions: true,
                        onEdit: beginEditing,
                        onDelete: gameMapStore.delete
                    )
                }

                Spacer()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Edit Course", isPresented: $showsEditDialog) {
            TextField("Name", text: $editedMapName)

            Button("Cancel", role: .cancel) {}

            Button("Save") {
                saveEditedMap()
            }
            .disabled(
                editedMapName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            )
        } message: {
            Text("Rename this course.")
        }
    }

    private func beginEditing(_ map: GameMap) {
        editingMap = map
        editedMapName = map.name
        showsEditDialog = true
    }

    private func saveEditedMap() {
        let name = editedMapName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard var map = editingMap, name.isEmpty == false else {
            return
        }

        map.name = name
        gameMapStore.save(map)
        editingMap = nil
        editedMapName = ""
    }
}

#Preview {
    CoursesView(
        eduardModelStore: EduardModelStore(),
        gameMapStore: GameMapStore()
    )
}
