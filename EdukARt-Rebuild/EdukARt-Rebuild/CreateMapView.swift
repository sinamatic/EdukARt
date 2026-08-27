//
//  CreateMapView.swift
//  EdukARt-Rebuild
//
//  Provides the user interface for creating a new map.
//

import SwiftUI
import SwiftUIJoystick

struct CreateMapView: View {

    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var mapBuilder: AprilTagMapBuilder
    @ObservedObject var gameMapStore: GameMapStore

    @Environment(\.dismiss) private var dismiss

    @StateObject private var joystickMonitor = JoystickMonitor()
    @StateObject private var turnJoystickMonitor = JoystickMonitor()
    @StateObject private var course = Course()

    @State private var creationStep = CreationStep.createMap
    @State private var mapName = ""
    @State private var showNameDialog = false

    private let mapSizeFactor: CGFloat = 2.0 / 3.0
    private let items = [
        ("👅", "Tongue"),
        ("🥚", "Eggs"),
        ("💩", "Shit")
    ]
    private let obstacles = [
        ("🛢", "Oil"),
        ("💧", "Water"),
        ("🪨", "Rock"),
        ("🌳", "Tree")
    ]

    private var footerHeight: CGFloat {
        creationStep == .itemsObstacles ? 250 : 116
    }

    private var showsCamera: Bool {
        creationStep == .createMap && showNameDialog == false
    }

    private var canContinue: Bool {
        switch creationStep {
        case .createMap:
            mapBuilder.referenceTagID != nil
        case .drawRoad, .itemsObstacles:
            true
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let mapSize = min(geometry.size.width, geometry.size.height) * mapSizeFactor
            let mapCenterX = geometry.size.width / 2
            let mapCenterY = geometry.size.height / 2
            let mapLeftX = mapCenterX - mapSize / 2
            let mapRightX = mapCenterX + mapSize / 2
            let mapTopY = mapCenterY - mapSize / 2

            ZStack {
                backgroundView
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                VStack(spacing: 0) {
                    Color.black.opacity(0.5).frame(height: 190)
                    Color.black.opacity(0.2)
                    Color.black.opacity(0.5).frame(height: 160)
                }

                AprilTagMapView(
                    mapBuilder: mapBuilder,
                    course: course,
                    mapWidthFactor: 1.0,
                    mapAlignment: .center,
                    showsClearCourseButton: false,
                    allowsCourseDrawing: creationStep == .drawRoad,
                    backgroundColor: showsCamera ? Color.black.opacity(0.52) : Color.black
                )
                .frame(width: mapSize, height: mapSize)
                .position(x: mapCenterX, y: mapCenterY)

                stepControls(
                    mapLeftX: mapLeftX,
                    mapRightX: mapRightX,
                    mapTopY: mapTopY,
                    mapCenterY: mapCenterY,
                    screenWidth: geometry.size.width,
                    screenHeight: geometry.size.height
                )

                VStack(spacing: 0) {
                    headerView
                        .frame(height: 190, alignment: .top)
                        .padding(.horizontal, 24)
                        .padding(.top, 38)

                    Spacer()

                    footerView
                        .frame(height: footerHeight, alignment: .bottom)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 62)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            mapBuilder.reset()
            course.reset()
            mapName = ""
            creationStep = .createMap
        }
        .alert("Course Name", isPresented: $showNameDialog) {
            TextField("Name", text: $mapName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saveMap() }
                .disabled(mapName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a name for the new course.")
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(creationStep.stepLabel)
                    .font(.headline.bold())
                    .foregroundStyle(.white.opacity(0.82))

                Text(creationStep.title)
                    .mapMenuTitleStyle()
            }

            if creationStep == .drawRoad {
                drawRoadHint
            } else {
                Text(creationStep.subtitle(referenceTagID: mapBuilder.referenceTagID))
                    .mapMenuSubtitleStyle()
                    .lineLimit(4)
                    .frame(height: 92, alignment: .top)
            }
        }
    }

    private var drawRoadHint: some View {
        VStack(spacing: 8) {
            Text(creationStep.subtitle(referenceTagID: mapBuilder.referenceTagID))
                .mapMenuSubtitleStyle()

            HStack(spacing: 14) {
                labelDot(color: .yellow, text: "Yellow = Start")
                labelDot(color: .green, text: "Green = End")
            }
            .font(.caption.bold())
            .foregroundStyle(.white.opacity(0.82))
        }
        .frame(height: 92, alignment: .top)
    }

    private func labelDot(
        color: Color,
        text: String
    ) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(text)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if showsCamera {
            CameraARView(
                eduardModelStore: eduardModelStore,
                joystickMonitor: joystickMonitor,
                turnJoystickMonitor: turnJoystickMonitor,
                mapBuilder: mapBuilder
            )
        } else {
            ZStack {
                Image("Keyvisual")
                    .resizable()
                    .scaledToFill()

                Color.black
                    .opacity(0.9)
            }
        }
    }

    private func stepControls(
        mapLeftX: CGFloat,
        mapRightX: CGFloat,
        mapTopY: CGFloat,
        mapCenterY: CGFloat,
        screenWidth: CGFloat,
        screenHeight: CGFloat
    ) -> some View {
        ZStack {
            if let previousStep = creationStep.previousStep {
                stepArrow(
                    systemName: "chevron.left.circle.fill",
                    targetStep: previousStep
                )
                .position(
                    x: max(mapLeftX - 64, 36),
                    y: mapCenterY
                )
            }

            if let nextStep = creationStep.nextStep, canContinue {
                stepArrow(
                    systemName: "chevron.right.circle.fill",
                    targetStep: nextStep
                )
                .position(
                    x: min(mapRightX + 84, screenWidth - 36),
                    y: mapCenterY
                )
            }

            Button("Reset") {
                resetCurrentStep()
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .position(
                x: min(mapRightX - 34, screenWidth - 48),
                y: max(mapTopY - 34, 44)
            )
        }
    }

    private func stepArrow(
        systemName: String,
        targetStep: CreationStep
    ) -> some View {
        Button {
            creationStep = targetStep
        } label: {
            Image(systemName: systemName)
                .font(.largeTitle)
                .foregroundStyle(.white)
        }
    }

    private func resetCurrentStep() {
        switch creationStep {
        case .createMap:
            mapBuilder.reset()
            course.reset()
        case .drawRoad:
            course.reset()
        case .itemsObstacles:
            break
        }
    }

    private var footerView: some View {
        VStack(spacing: 14) {
            if creationStep == .itemsObstacles {
                objectPaletteView
            }

            Text(creationStep.footerText(tagCount: mapBuilder.mapPoints.count))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Button(creationStep.primaryButtonTitle) {
                guard canContinue else {
                    return
                }

                if creationStep == .itemsObstacles {
                    showNameDialog = true
                } else if let nextStep = creationStep.nextStep {
                    creationStep = nextStep
                }
            }
            .buttonStyle(MapMenuButtonStyle(color: Color("BrandGreen")))
            .disabled(canContinue == false)
            .opacity(canContinue ? 1 : 0.45)
        }
    }

    private var objectPaletteView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 18) {
                paletteSection(title: "Items", options: items)
                paletteSection(title: "Obstacles", options: obstacles)
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 118)
    }

    private func paletteSection(
        title: String,
        options: [(String, String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.75))

            HStack(spacing: 10) {
                ForEach(options, id: \.1) { option in
                    objectTile(symbol: option.0, name: option.1)
                }
            }
        }
    }

    private func objectTile(
        symbol: String,
        name: String
    ) -> some View {
        VStack(spacing: 6) {
            Text(symbol)
                .font(.system(size: 30))
                .frame(height: 36)

            Text(name)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 82, height: 78)
        .background(Color.black.opacity(0.55))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func saveMap() {
        let name = mapName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard name.isEmpty == false,
              let gameMap = mapBuilder.createGameMap(name: name) else {
            return
        }

        gameMapStore.save(gameMap)
        mapName = ""
        dismiss()
    }
}

private enum CreationStep {
    case createMap
    case drawRoad
    case itemsObstacles

    var previousStep: CreationStep? {
        switch self {
        case .createMap:
            nil
        case .drawRoad:
            .createMap
        case .itemsObstacles:
            .drawRoad
        }
    }

    var nextStep: CreationStep? {
        switch self {
        case .createMap:
            .drawRoad
        case .drawRoad:
            .itemsObstacles
        case .itemsObstacles:
            nil
        }
    }

    var stepLabel: String {
        switch self {
        case .createMap:
            "Step 1/3"
        case .drawRoad:
            "Step 2/3"
        case .itemsObstacles:
            "Step 3/3"
        }
    }

    var title: String {
        switch self {
        case .createMap:
            "Create Map"
        case .drawRoad:
            "Draw Road"
        case .itemsObstacles:
            "Items / Obstacles"
        }
    }

    func subtitle(referenceTagID: Int?) -> String {
        switch self {
        case .createMap:
            referenceTagID == nil
            ? "Scan the first AprilTag carefully: the red reference tag is where the map must be placed when the game starts."
            : "The red reference tag anchors the map in the game. Continue scanning the remaining AprilTags."
        case .drawRoad:
            "Draw the road in one stroke."
        case .itemsObstacles:
            "Place items and obstacles on the mapped course."
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .createMap:
            "Next: Draw Road"
        case .drawRoad:
            "Next: Add Items"
        case .itemsObstacles:
            "Save Course"
        }
    }

    func footerText(tagCount: Int) -> String {
        switch self {
        case .createMap:
            "\(tagCount) AprilTags mapped"
        case .drawRoad:
            "Draw Road"
        case .itemsObstacles:
            "Items / Obstacles"
        }
    }
}
