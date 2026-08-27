//
//  StartGameView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 20.08.26.
//

import SwiftUI

struct StartGameView: View {

    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var controller: RobotController
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
                            controller: controller,
                            gameMapStore: gameMapStore
                        )
                    } label: {
                        Text("Edit Courses")
                    }
                    .buttonStyle(MapMenuButtonStyle(color: Color("BlackOverlay")))

                    if let selectedMap {
                        NavigationLink {
                            GameView(
                                eduardModelStore:
                                    eduardModelStore,

                                controller:
                                    controller,

                                map:
                                    selectedMap
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

    var fillsHeight = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .frame(maxHeight: fillsHeight ? .infinity : nil, alignment: .top)
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
                .frame(maxHeight: 366)
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
            ? Color("BrandGreen").opacity(0.42)
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
    var robotPose:
        RobotPose? = nil


    var body: some View {

        GeometryReader { geometry in

            let bounds =
                previewBounds

            let size =
                min(
                    geometry.size.width,
                    geometry.size.height
                )

            let scale =
                min(
                    (size - 18)
                        / CGFloat(bounds.width),

                    (size - 18)
                        / CGFloat(bounds.height)
                )


            ZStack {

                Color.black
                    .opacity(0.35)


                // MARK: - Track

                trackPreview(
                    bounds:
                        bounds,

                    scale:
                        scale
                )


                // MARK: - AprilTags

                ForEach(
                    map.aprilTags
                ) { tag in

                    Rectangle()
                        .fill(
                            Color.black
                        )
                        .overlay {

                            Rectangle()
                                .stroke(
                                    tag.id
                                        == map.referenceTagID
                                    ? Color.red.opacity(0.85)
                                    : Color.white,

                                    lineWidth:
                                        1
                                )
                        }
                        .frame(
                            width: 12,
                            height: 12
                        )
                        .overlay {

                            Text(
                                "\(tag.id)"
                            )
                            .font(
                                .system(
                                    size:
                                        7,

                                    weight:
                                        .bold
                                )
                            )
                            .foregroundStyle(
                                .white
                            )
                        }
                        .position(

                            x:
                                9
                                + CGFloat(
                                    tag.x
                                    - bounds.minX
                                )
                                * scale,

                            y:
                                9
                                + CGFloat(
                                    tag.z
                                    - bounds.minZ
                                )
                                * scale
                        )
                }


                if let robotPose {

                    Rectangle()
                        .fill(
                            Color.blue
                        )
                        .frame(
                            width: 14,
                            height: 14
                        )
                        .overlay {

                            Text(
                                "0"
                            )
                            .font(
                                .system(
                                    size:
                                        8,

                                    weight:
                                        .bold
                                )
                            )
                            .foregroundStyle(
                                .white
                            )
                        }
                        .rotationEffect(
                            .radians(
                                Double(
                                    robotPose.rotation
                                )
                            )
                        )
                        .position(

                            x:
                                9
                                + CGFloat(
                                    robotPose.position.x
                                    - bounds.minX
                                )
                                * scale,

                            y:
                                9
                                + CGFloat(
                                    robotPose.position.z
                                    - bounds.minZ
                                )
                                * scale
                        )
                }
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 10
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius: 10
                )
                .stroke(
                    Color.white.opacity(0.45),
                    lineWidth: 1.5
                )
            }
            .shadow(
                color:
                    .black.opacity(0.28),

                radius:
                    4,

                y:
                    2
            )
        }
    }


    // MARK: - Track Preview

    @ViewBuilder
    private func trackPreview(
        bounds: PreviewBounds,
        scale: CGFloat
    ) -> some View {

        let points =
            map.trackPoints


        if points.count >= 2 {

            let segmentCount =
                points.count - 1


            ForEach(
                0..<segmentCount,
                id: \.self
            ) { index in

                let progress =
                    CGFloat(index)
                    / CGFloat(
                        max(
                            segmentCount - 1,
                            1
                        )
                    )


                let start =
                    points[index]

                let end =
                    points[index + 1]


                Path { path in

                    path.move(
                        to:
                            CGPoint(
                                x:
                                    9
                                    + CGFloat(
                                        start.x
                                        - bounds.minX
                                    )
                                    * scale,

                                y:
                                    9
                                    + CGFloat(
                                        start.z
                                        - bounds.minZ
                                    )
                                    * scale
                            )
                    )


                    path.addLine(
                        to:
                            CGPoint(
                                x:
                                    9
                                    + CGFloat(
                                        end.x
                                        - bounds.minX
                                    )
                                    * scale,

                                y:
                                    9
                                    + CGFloat(
                                        end.z
                                        - bounds.minZ
                                    )
                                    * scale
                            )
                    )
                }
                .stroke(
                    courseColor(
                        at:
                            progress
                    ),
                    style:
                        StrokeStyle(
                            lineWidth: 2.5,
                            lineCap: .round,
                            lineJoin: .round
                        )
                )
            }
        }
    }


    // MARK: - Track Color

    private func courseColor(
        at progress: CGFloat
    ) -> Color {

        Color(
            red:
                1 - progress,

            green:
                0.85
                + progress * 0.15,

            blue:
                0
        )
    }


    // MARK: - Bounds

    private var previewBounds:
        PreviewBounds {

        // Include both AprilTags AND track points.
        let xValues =
            map.aprilTags.map {
                $0.x
            }
            +
            map.trackPoints.map {
                $0.x
            }
            +
            (
                robotPose.map {
                    [
                        $0.position.x
                    ]
                }
                ?? []
            )


        let zValues =
            map.aprilTags.map {
                $0.z
            }
            +
            map.trackPoints.map {
                $0.z
            }
            +
            (
                robotPose.map {
                    [
                        $0.position.z
                    ]
                }
                ?? []
            )


        let minX =
            xValues.min() ?? 0

        let maxX =
            xValues.max() ?? 0

        let minZ =
            zValues.min() ?? 0

        let maxZ =
            zValues.max() ?? 0


        let realWidth =
            maxX - minX

        let realHeight =
            maxZ - minZ


        let width =
            max(
                realWidth,
                1
            )

        let height =
            max(
                realHeight,
                1
            )


        let extraX =
            (
                width
                - realWidth
            )
            / 2

        let extraZ =
            (
                height
                - realHeight
            )
            / 2


        return PreviewBounds(
            minX:
                minX - extraX,

            minZ:
                minZ - extraZ,

            width:
                width,

            height:
                height
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
        controller: RobotController(),
        gameMapStore: GameMapStore()
    )
}
