//
//  StartGameView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI

struct StartGameView: View {

    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var gameMapStore: GameMapStore

    @State private var selectedMapID: GameMap.ID?

    private var selectedMap: GameMap? {
        gameMapStore.maps.first { $0.id == selectedMapID }
    }

    var body: some View {
        MapMenuBackground {
            VStack(spacing: 20) {
                MapMenuPanel {
                    Text("Select Course")
                        .mapMenuTitleStyle()

                    Text("Select a Course to start the game or go to Courses to create or edit them.")
                        .mapMenuSubtitleStyle()

                    SavedMapsListView(
                        gameMapStore: gameMapStore,
                        selectedMapID: selectedMapID,
                        onSelect: { selectedMapID = $0.id }
                    )
                }

                Spacer(minLength: 12)

                VStack(spacing: 12) {
                    NavigationLink {
                        CoursesView(
                            eduardModelStore: eduardModelStore,
                            gameMapStore: gameMapStore
                        )
                    } label: {
                        Text("Edit Courses")
                    }
                    .buttonStyle(MapMenuButtonStyle(color: Color("BlackOverlay")))

                    if let selectedMap {
                        NavigationLink {
                            GameView(
                                eduardModelStore: eduardModelStore
                            )
                        } label: {
                            Text("Start Game")
                        }
                        .buttonStyle(MapMenuButtonStyle(color: Color("BrandGreen")))
                        .accessibilityLabel("Start Game with \(selectedMap.name)")
                    }
                }
                .padding(.bottom, 96)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectFirstMapIfNeeded()
        }
        .onChange(of: gameMapStore.maps.count) { _, _ in
            selectFirstMapIfNeeded()
        }
    }

    private func selectFirstMapIfNeeded() {
        guard gameMapStore.maps.contains(where: { $0.id == selectedMapID }) == false else {
            return
        }

        selectedMapID = gameMapStore.maps.first?.id
    }
}

struct MapMenuBackground<Content: View>: View {

    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Image("Keyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black
                .opacity(0.58)
                .ignoresSafeArea()

            content
                .padding(.horizontal, 30)
                .padding(.top, 192)
        }
    }
}

struct MapMenuPanel<Content: View>: View {

    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(18)
        .background(Color.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct SavedMapsListView: View {

    @ObservedObject var gameMapStore: GameMapStore

    var selectedMapID: GameMap.ID?
    var onSelect: ((GameMap) -> Void)?
    var showsCourseActions = false
    var onEdit: ((GameMap) -> Void)?
    var onDelete: ((GameMap) -> Void)?

    var body: some View {
        Group {
            if gameMapStore.maps.isEmpty {
                Text("No saved maps yet")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color("BlackOverlay"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                List {
                    ForEach(gameMapStore.maps) { map in
                        mapRow(for: map)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if showsCourseActions {
                                    Button("Delete", role: .destructive) {
                                        onDelete?(map)
                                    }

                                    Button("Edit") {
                                        onEdit?(map)
                                    }
                                    .tint(Color("BrandGreen"))
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(maxHeight: 320)
            }
        }
    }

    @ViewBuilder
    private func mapRow(for map: GameMap) -> some View {
        if let onSelect {
            Button {
                onSelect(map)
            } label: {
                MapCardView(
                    map: map,
                    isSelected: selectedMapID == map.id
                )
            }
            .buttonStyle(.plain)
        } else {
            MapCardView(
                map: map,
                isSelected: selectedMapID == map.id
            )
        }
    }
}

struct MapCardView: View {

    let map: GameMap
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            GameMapPreview(map: map)
                .frame(width: 86, height: 86)

            VStack(alignment: .leading, spacing: 7) {
                Text(map.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Coins 0 | Items 0 | Obstacles 0")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))

                Text("Route - | Best Time -")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()
        }
        .padding(12)
        .background(
            isSelected
            ? Color("BrandGreen").opacity(0.28)
            : Color("BlackOverlay")
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    Color("BrandGreen"),
                    lineWidth: isSelected ? 3 : 1.5
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct GameMapPreview: View {

    let map: GameMap

    var body: some View {
        GeometryReader { geometry in
            let bounds = previewBounds
            let size = min(geometry.size.width, geometry.size.height)
            let scale = min(
                (size - 18) / CGFloat(bounds.width),
                (size - 18) / CGFloat(bounds.height)
            )

            ZStack {
                Color.black.opacity(0.35)

                ForEach(map.aprilTags) { tag in
                    Rectangle()
                        .fill(Color.black)
                        .overlay {
                            Rectangle()
                                .stroke(
                                    tag.id == map.referenceTagID ? Color.red.opacity(0.85) : Color.white,
                                    lineWidth: 1
                                )
                        }
                        .frame(width: 12, height: 12)
                        .position(
                            x: 9 + CGFloat(tag.x - bounds.minX) * scale,
                            y: 9 + CGFloat(tag.z - bounds.minZ) * scale
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.28), radius: 4, y: 2)
        }
    }

    private var previewBounds: PreviewBounds {
        let minX = map.aprilTags.map { $0.x }.min() ?? 0
        let maxX = map.aprilTags.map { $0.x }.max() ?? 0
        let minZ = map.aprilTags.map { $0.z }.min() ?? 0
        let maxZ = map.aprilTags.map { $0.z }.max() ?? 0
        let width = max(maxX - minX, 1)
        let height = max(maxZ - minZ, 1)
        let extraX = (width - (maxX - minX)) / 2
        let extraZ = (height - (maxZ - minZ)) / 2

        return PreviewBounds(
            minX: minX - extraX,
            minZ: minZ - extraZ,
            width: width,
            height: height
        )
    }
}

struct PreviewBounds {
    let minX: Float
    let minZ: Float
    let width: Float
    let height: Float
}

struct MapMenuButtonStyle: ButtonStyle {

    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .padding()
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension Text {

    func mapMenuTitleStyle() -> some View {
        font(.largeTitle.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 10)
    }

    func mapMenuSubtitleStyle() -> some View {
        font(.subheadline)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.75))
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    StartGameView(
        eduardModelStore: EduardModelStore(),
        gameMapStore: GameMapStore()
    )
}
