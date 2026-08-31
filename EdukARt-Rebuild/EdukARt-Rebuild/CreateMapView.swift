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
    @ObservedObject var controller: RobotController
    @ObservedObject var mapBuilder: AprilTagMapBuilder
    @ObservedObject var gameMapStore: GameMapStore
    let editingMap:
        GameMap?

    init(
        eduardModelStore: EduardModelStore,
        controller: RobotController,
        mapBuilder: AprilTagMapBuilder,
        gameMapStore: GameMapStore,
        editingMap: GameMap? = nil
    ) {

        self.eduardModelStore =
            eduardModelStore

        self.controller =
            controller

        self.mapBuilder =
            mapBuilder

        self.gameMapStore =
            gameMapStore

        self.editingMap =
            editingMap
    }

    @Environment(\.dismiss) private var dismiss

    @StateObject private var joystickMonitor = JoystickMonitor()
    @StateObject private var turnJoystickMonitor = JoystickMonitor()
    @StateObject private var course = Course()
    
    @State private var placedMapObjects: [PlacedMapObject] = []
    
    // AprilTag geometry is frozen when Step 1 is completed.
    // Steps 2 and 3 no longer depend on live measurements.
    @State private var frozenAprilTags:
        [StoredAprilTag] = []

    @State private var frozenReferenceTagID:
        Int?

    @State private var localizationResetID:
        Int = 0

    @State private var creationStep = CreationStep.createMap
    @State private var mapName = ""
    @State private var showNameDialog = false
    @State private var hasConfiguredInitialState = false

    private let mapSizeFactor: CGFloat = 2.0 / 3.0
    private let items:
        [MapObjectType] = [
            .tongue,
            .eggs,
            .shit
        ]

    private let obstacles:
        [MapObjectType] = [
            .oil,
            .water,
            .rock,
            .tree
        ]

    private var footerHeight: CGFloat {
        creationStep == .itemsObstacles ? 250 : 116
    }

    private var showsCamera: Bool {
        creationStep == .createMap && showNameDialog == false
    }

    private var isEditingExistingMap: Bool {
        editingMap != nil
    }

    private var canContinue: Bool {

        switch creationStep {

        case .createMap:

            return
                mapBuilder.referenceTagID != nil
                && mapBuilder.mapPoints.isEmpty == false


        case .drawRoad:

            return
                course.trackPoints.count >= 2


        case .itemsObstacles:

            return true
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

                if creationStep == .createMap {

                    // ----------------------------------------------
                    // STEP 1
                    // Live AprilTag measurement preview
                    // ----------------------------------------------

                    AprilTagMapView(
                        mapBuilder:
                            mapBuilder,

                        course:
                            course,

                        mapWidthFactor:
                            1.0,

                        mapAlignment:
                            .center,

                        showsClearCourseButton:
                            false,

                        allowsCourseDrawing:
                            false,

                        backgroundColor:
                            showsCamera
                            ? Color.black.opacity(0.52)
                            : Color.black
                    )
                    .frame(
                        width:
                            mapSize,

                        height:
                            mapSize
                    )
                    .position(
                        x:
                            mapCenterX,

                        y:
                            mapCenterY
                    )

                } else if let referenceTagID =
                    frozenReferenceTagID {

                    // ----------------------------------------------
                    // STEP 2 + STEP 3
                    // Frozen persistent map geometry
                    // ----------------------------------------------

                    GameMapView(
                        aprilTags:
                            frozenAprilTags,

                        referenceTagID:
                            referenceTagID,

                        course:
                            course,
                        
                        allowsCourseDrawing:
                                creationStep == .drawRoad,
                        
                        mapObjects:
                                $placedMapObjects,
                      
                        allowsObjectPlacement:
                                creationStep == .itemsObstacles,

                        backgroundColor:
                            .black,

                        borderColor:
                            .white.opacity(0.7),

                        borderLineWidth:
                            1
                    )
                    .frame(
                        width:
                            mapSize,

                        height:
                            mapSize
                    )
                    .position(
                        x:
                            mapCenterX,

                        y:
                            mapCenterY
                    )
                }
                
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
        .background(
            SwipeBackDisabler()
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            configureInitialStateIfNeeded()
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


    private func configureInitialStateIfNeeded() {

        guard hasConfiguredInitialState == false
        else {
            return
        }


        hasConfiguredInitialState =
            true


        if let editingMap {

            mapBuilder.reset()

            course.load(
                storedTrackPoints:
                    editingMap.trackPoints
            )

            frozenAprilTags =
                editingMap.aprilTags

            frozenReferenceTagID =
                editingMap.referenceTagID

            placedMapObjects =
                editingMap.mapObjects

            mapName =
                editingMap.name

            creationStep =
                .drawRoad

        } else {

            mapBuilder.reset()

            course.reset()

            frozenReferenceTagID =
                nil

            mapName =
                ""

            creationStep =
                .createMap

            placedMapObjects.removeAll()
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
                mapBuilder: mapBuilder,
                controller: controller,
                localizationResetID: localizationResetID
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
                if isEditingExistingMap == false
                    || creationStep != .drawRoad {

                    stepArrow(
                        systemName: "chevron.left.circle.fill",
                        targetStep: previousStep
                    )
                    .position(
                        x: max(mapLeftX - 64, 36),
                        y: mapCenterY
                    )
                }
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

            changeStep(
                to:
                    targetStep
            )

        } label: {
            Image(systemName: systemName)
                .font(.largeTitle)
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Change Step

    private func changeStep(
        to targetStep: CreationStep
    ) {

        // Leaving Step 1 freezes the AprilTag geometry.
        if creationStep == .createMap,
           targetStep == .drawRoad {

            freezeAprilTagMap()
        }


        creationStep =
            targetStep
    }
    
    // MARK: - Freeze AprilTag Map

    private func freezeAprilTagMap() {

        guard let referenceTagID =
            mapBuilder.referenceTagID
        else {
            return
        }


        frozenReferenceTagID =
            referenceTagID


        frozenAprilTags =
            mapBuilder.mapPoints.map { point in

                StoredAprilTag(
                    id:
                        point.id,

                    x:
                        point.x,

                    z:
                        point.z,

                    rotation:
                        point.rotation
                )
            }


        print(
            "# MAP FROZEN | Reference ID \(referenceTagID)"
        )
    }

    private func resetCurrentStep() {

        switch creationStep {

        case .createMap:

            mapBuilder.reset()

            course.reset()

            frozenAprilTags.removeAll()

            frozenReferenceTagID =
                nil

            localizationResetID += 1


        case .drawRoad:

            course.reset()


        case .itemsObstacles:
            placedMapObjects.removeAll()
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
                    if isEditingExistingMap {

                        saveMap()

                    } else {

                        showNameDialog = true
                    }
                } else if let nextStep =
                    creationStep.nextStep {

                    changeStep(
                        to:
                            nextStep
                    )
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
        options: [MapObjectType]
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                8
        ) {

            Text(title)
                .font(.caption.bold())
                .foregroundStyle(
                    .white.opacity(0.75)
                )


            HStack(spacing: 10) {

                ForEach(
                    options,
                    id:
                        \.self
                ) { type in

                    objectTile(
                        type:
                            type
                    )
                }
            }
        }
    }

    private func objectTile(
        type: MapObjectType
    ) -> some View {

        return VStack(spacing: 6) {

            Text(type.symbol)
                .font(
                    .system(
                        size:
                            30
                    )
                )
                .frame(
                    height:
                        36
                )


            Text(type.name)
                .font(
                    .caption2.bold()
                )
                .foregroundStyle(
                    .white
                )
                .lineLimit(1)
                .minimumScaleFactor(
                    0.75
                )
        }
        .frame(
            width:
                82,

            height:
                78
        )
        .background(
            Color.black.opacity(
                0.55
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    12
            )
            .stroke(
                Color.white.opacity(
                    0.28
                ),
                lineWidth:
                    1
            )
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    12
            )
        )

        .draggable(
            type.rawValue
        )
    }

    // MARK: - Save Map

    private func saveMap() {

        let name =
            mapName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard name.isEmpty == false,
              let referenceTagID =
                frozenReferenceTagID
        else {
            return
        }


        let gameMap =
            GameMap(
                id:
                    editingMap?.id
                    ?? UUID(),

                name:
                    editingMap?.name
                    ?? name,

                createdAt:
                    editingMap?.createdAt
                    ?? Date(),

                referenceTagID:
                    referenceTagID,

                aprilTags:
                    frozenAprilTags,

                trackPoints:
                    course.storedTrackPoints(),
                
                mapObjects:
                           placedMapObjects
            )


        print(
            "# MAP SAVED | Reference ID \(referenceTagID) | Objects \(placedMapObjects.count)"
        )


        gameMapStore.save(
            gameMap
        )


        mapName =
            ""

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
            "Hold an item, then place it on the mapped course."
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
