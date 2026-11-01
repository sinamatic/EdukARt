import SwiftUI
import UniformTypeIdentifiers

struct SpectatorGhostLibraryView: View {
    @ObservedObject var eduardModelStore: EduardModelStore
    @ObservedObject var controller: RobotController
    @ObservedObject var gameMapStore: GameMapStore

    @StateObject private var library = SpectatorGhostLibrary()
    @State private var selectedIDs: Set<UUID> = []
    @State private var isImporting = false
    @State private var isEditing = false
    @State private var sortOrder: SpectatorGhostSortOrder = .dateAscending
    @State private var sessionGhosts: [SpectatorGhost] = []
    @State private var sessionMaps: [GameMap] = []
    @State private var showsPlayback = false
    @State private var validationMessage: String?

    var body: some View {
        SpectatorLibraryContent(
            ghosts: sortedGhosts,
            selectedIDs: $selectedIDs,
            isEditing: isEditing,
            sortOrder: $sortOrder,
            onImport: { isImporting = true },
            onToggleEditing: { isEditing.toggle() },
            onSelectAll: selectAll,
            onDelete: deleteSelection,
            onStart: startSpectatorMode
        )
        .navigationTitle("Spectator Mode")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                library.importGhosts(from: urls)
            case .failure(let error):
                validationMessage = error.localizedDescription
            }
        }
        .alert(
            "Ghost Import",
            isPresented: Binding(
                get: {
                    validationMessage != nil || library.errorMessage != nil
                },
                set: { isPresented in
                    if isPresented == false {
                        validationMessage = nil
                        library.clearError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage ?? library.errorMessage ?? "")
        }
        .navigationDestination(isPresented: $showsPlayback) {
            if sessionMaps.isEmpty == false {
                SpectatorPlaybackView(
                    maps: sessionMaps,
                    ghosts: sessionGhosts,
                    eduardModelStore: eduardModelStore,
                    controller: controller
                )
            }
        }
    }

    private var sortedGhosts: [SpectatorGhost] {
        library.ghosts.sorted(using: sortOrder)
    }

    private func selectAll() {
        if selectedIDs.count == library.ghosts.count {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(library.ghosts.map(\.id))
        }
    }

    private func deleteSelection() {
        library.delete(ids: selectedIDs)
        selectedIDs.removeAll()
        isEditing = false
    }

    private func startSpectatorMode() {
        let selected = library.ghosts.filter {
            selectedIDs.contains($0.id)
        }

        guard selected.isEmpty == false else {
            validationMessage = "Select at least one ghost."
            return
        }

        let selectedMapIDs = Set(selected.map(\.mapID))

        guard selectedMapIDs.count <= 3 else {
            validationMessage = "Select ghosts from no more than three courses."
            return
        }

        let maps = selectedMapIDs.compactMap { mapID in
            gameMapStore.maps.first(where: { $0.id == mapID })
        }

        guard maps.count == selectedMapIDs.count else {
            let installedIDs = Set(maps.map(\.id))
            let missingName = selected.first {
                installedIDs.contains($0.mapID) == false
            }?.mapName ?? "Unknown course"
            validationMessage = "The course “\(missingName)” is not installed on this iPad."
            return
        }

        guard Set(maps.map(\.referenceTagID)).count == 1 else {
            validationMessage = "The selected courses must use the same reference AprilTag."
            return
        }

        sessionMaps = maps.sorted { $0.name < $1.name }
        sessionGhosts = Self.interleavedPlaybackQueue(from: selected)
        showsPlayback = true
    }

    private static func interleavedPlaybackQueue(
        from ghosts: [SpectatorGhost]
    ) -> [SpectatorGhost] {
        let groups = Dictionary(grouping: ghosts, by: \.mapID)
            .values
            .map { group in
                group.sorted { first, second in
                    first.ranks(before: second)
                }
            }
            .sorted {
                ($0.first?.mapName ?? "") < ($1.first?.mapName ?? "")
            }

        let maximumCount = groups.map(\.count).max() ?? 0
        var queue: [SpectatorGhost] = []

        for rankIndex in 0..<maximumCount {
            for group in groups where group.indices.contains(rankIndex) {
                queue.append(group[rankIndex])
            }
        }

        return queue
    }
}

private struct SpectatorLibraryContent: View {
    let ghosts: [SpectatorGhost]
    @Binding var selectedIDs: Set<UUID>
    let isEditing: Bool
    @Binding var sortOrder: SpectatorGhostSortOrder
    let onImport: () -> Void
    let onToggleEditing: () -> Void
    let onSelectAll: () -> Void
    let onDelete: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            SpectatorLibraryActions(
                hasGhosts: ghosts.isEmpty == false,
                hasSelection: selectedIDs.isEmpty == false,
                isEditing: isEditing,
                allSelected: ghosts.isEmpty == false
                    && selectedIDs.count == ghosts.count,
                sortOrder: $sortOrder,
                onImport: onImport,
                onToggleEditing: onToggleEditing,
                onSelectAll: onSelectAll,
                onDelete: onDelete
            )

            if ghosts.isEmpty {
                ContentUnavailableView(
                    "No Ghosts",
                    systemImage: "car.side",
                    description: Text("Import one or more ghost JSON files.")
                )
                .frame(maxHeight: .infinity)
            } else {
                SpectatorGhostTable(
                    ghosts: ghosts,
                    selectedIDs: $selectedIDs
                )
            }

            Button("Start Spectator Mode", action: onStart)
                .buttonStyle(.borderedProminent)
                .tint(Color("BrandGreen"))
                .disabled(selectedIDs.isEmpty)
                .controlSize(.large)
        }
        .padding(24)
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
    }
}

private struct SpectatorLibraryActions: View {
    let hasGhosts: Bool
    let hasSelection: Bool
    let isEditing: Bool
    let allSelected: Bool
    @Binding var sortOrder: SpectatorGhostSortOrder
    let onImport: () -> Void
    let onToggleEditing: () -> Void
    let onSelectAll: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onImport) {
                Label("Import Ghosts", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("BrandGreen"))

            Button(isEditing ? "Done" : "Edit", action: onToggleEditing)
                .buttonStyle(.bordered)
                .disabled(hasGhosts == false)

            if isEditing {
                Button("Delete Selected", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
                    .disabled(hasSelection == false)
            }

            Button(
                allSelected ? "Deselect All" : "Select All",
                action: onSelectAll
            )
            .buttonStyle(.bordered)
            .disabled(hasGhosts == false)

            Spacer()

            Picker("Sort", selection: $sortOrder) {
                ForEach(SpectatorGhostSortOrder.allCases) { order in
                    Text(order.title).tag(order)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

private struct SpectatorGhostTable: View {
    let ghosts: [SpectatorGhost]
    @Binding var selectedIDs: Set<UUID>

    var body: some View {
        Table(ghosts, selection: $selectedIDs) {
            TableColumn("") { ghost in
                Image(
                    systemName: selectedIDs.contains(ghost.id)
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(
                    selectedIDs.contains(ghost.id)
                        ? Color("BrandGreen")
                        : .secondary
                )
                .onTapGesture {
                    toggle(ghost.id)
                }
            }
            .width(36)

            TableColumn("Player Name") { ghost in
                Text(ghost.playerName)
            }

            TableColumn("Course") { ghost in
                Text(ghost.mapName)
            }

            TableColumn("Eduard") { ghost in
                Text(ghost.eduardType?.displayName ?? "Unknown")
            }

            TableColumn("Time") { ghost in
                Text(formattedTime(ghost.duration))
                    .monospacedDigit()
            }

            TableColumn("Date and Time") { ghost in
                Text(
                    ghost.startedAt.formatted(
                        date: .numeric,
                        time: .shortened
                    )
                )
            }
        }
        .scrollContentBackground(.hidden)
        .onTapGesture {
            // Table manages row selection. The checkmark offers reliable
            // multi-selection for touch-only use.
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func formattedTime(_ interval: TimeInterval) -> String {
        String(
            format: "%d:%05.2f",
            Int(interval) / 60,
            interval.truncatingRemainder(dividingBy: 60)
        )
    }
}

enum SpectatorGhostSortOrder: String, CaseIterable, Identifiable {
    case dateAscending
    case dateDescending
    case timeAscending
    case timeDescending

    var id: Self { self }

    var title: String {
        switch self {
        case .dateAscending:
            "Date: Oldest First"
        case .dateDescending:
            "Date: Newest First"
        case .timeAscending:
            "Time: Fastest First"
        case .timeDescending:
            "Time: Slowest First"
        }
    }
}

private extension Array where Element == SpectatorGhost {
    func sorted(using order: SpectatorGhostSortOrder) -> Self {
        sorted { first, second in
            switch order {
            case .dateAscending:
                first.startedAt < second.startedAt
            case .dateDescending:
                first.startedAt > second.startedAt
            case .timeAscending:
                first.duration < second.duration
            case .timeDescending:
                first.duration > second.duration
            }
        }
    }
}
