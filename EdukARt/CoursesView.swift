//
//  CoursesView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct CoursesView: View {

    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var controller: RobotController
    @ObservedObject var gameMapStore: GameMapStore

    @StateObject private var mapBuilder = AprilTagMapBuilder()

    @State private var editingMap: GameMap?
    @State private var isShowingEditView = false
    @State private var courseExportURL: URL?
    @State private var courseExportError = false
    @State private var isShowingImporter = false
    @State private var showsImportResult = false
    @State private var importMessage = ""

    var body: some View {
        MapMenuBackground {
            MapMenuPanel(fillsHeight: true) {
                Text("Courses")
                    .mapMenuTitleStyle()

                NavigationLink {
                    CreateMapView(
                        eduardModelStore: eduardModelStore,
                        controller: controller,
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

                Text("Swipe a course to edit or delete it.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))

                SavedMapsListView(
                    gameMapStore: gameMapStore,
                    showsCourseActions: true,
                    onEdit: beginEditing,
                    onDelete: gameMapStore.delete
                )

                Button("Export all courses") {
                    prepareCourseExport()
                }
                .buttonStyle(MapMenuButtonStyle(color: Color("BlackOverlay")))

                if let courseExportURL {
                    ShareLink(item: courseExportURL) {
                        Label("Share courses", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(MapMenuButtonStyle(color: Color("BrandGreen")))
                }

                if courseExportError {
                    Text("The course export could not be prepared.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Import courses") {
                    isShowingImporter = true
                }
                .buttonStyle(MapMenuButtonStyle(color: Color("BlackOverlay")))

            }
            .padding(.bottom, 50)
        }
        .onAppear {

            controller.resetForManualControl()
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importCourses(result)
        }
        .alert("Import courses", isPresented: $showsImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importMessage)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(
            isPresented:
                $isShowingEditView
        ) {

            if let editingMap {

                CreateMapView(
                    eduardModelStore:
                        eduardModelStore,

                    controller:
                        controller,

                    mapBuilder:
                        mapBuilder,

                    gameMapStore:
                        gameMapStore,

                    editingMap:
                        editingMap
                )

            } else {

                EmptyView()
            }
        }
    }

    private func beginEditing(_ map: GameMap) {

        editingMap =
            map

        isShowingEditView =
            true
    }

    private func importCourses(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }

            let summary = try gameMapStore.importCourses(from: url)
            courseExportURL = nil
            importMessage = "Imported: \(summary.imported). Already present: \(summary.skipped)."
        } catch {
            importMessage = "The courses could not be imported. Please select an exported course JSON file.\n\n" + error.localizedDescription
        }
        showsImportResult = true
    }

    private func prepareCourseExport() {
        do {
            courseExportURL = try gameMapStore.exportAllCourses()
            courseExportError = false
        } catch {
            courseExportURL = nil
            courseExportError = true
        }
    }
}

#Preview {
    CoursesView(
        eduardModelStore: EduardModelStore(),
        controller: RobotController(),
        gameMapStore: GameMapStore()
    )
}
