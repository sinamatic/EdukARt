//
//  UIStartGameChooseMap.swift
//  EdukARt
//

import SwiftUI

struct UIStartGameChooseMap: View {
    @ObservedObject var mapStore: MapStore
    @State private var isEditingMaps = false
    @State private var deleteErrorMessage: String?
    let onBack: () -> Void
    let onCreateMap: () -> Void
    let onStartGame: (StoredFloorMap?) -> Void

    var body: some View {
        ZStack {
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(EdukARtUI.Opacity.mapSelectionOverlay)
                .ignoresSafeArea()

            VStack(spacing: EdukARtUI.Layout.mapSelectionSpacing) {
                HStack {
                    Button("Back") {
                        onBack()
                    }
                    .buttonStyle(CompactOverlayButtonStyle())

                    Button(isEditingMaps ? "Fertig" : "Bearbeiten") {
                        isEditingMaps.toggle()
                    }
                    .buttonStyle(CompactOverlayButtonStyle())

                    Spacer()
                }

                Text("Karte fuer Spiel waehlen")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text("Die Coins werden im Raster auf der gespeicherten Bodenflaeche platziert.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(EdukARtUI.Opacity.secondaryText))

                List {
                    Button {
                        onStartGame(nil)
                    } label: {
                        Text("Ohne Karte starten")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(EdukARtUI.Layout.listItemPadding)
                            .background(Color.white.opacity(EdukARtUI.Opacity.listItemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: EdukARtUI.Layout.listItemCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: EdukARtUI.Layout.listRowVerticalInset, leading: .zero, bottom: EdukARtUI.Layout.listRowVerticalInset, trailing: .zero))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    ForEach(mapStore.maps) { map in
                        mapRow(for: map)
                        .listRowInsets(EdgeInsets(top: EdukARtUI.Layout.listRowVerticalInset, leading: .zero, bottom: EdukARtUI.Layout.listRowVerticalInset, trailing: .zero))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)

                Button("Create Map") {
                    onCreateMap()
                }
                .buttonStyle(StartScreenButtonStyle(fillColor: EdukARtUI.Colors.brandGreen))
            }
            .padding(.horizontal, EdukARtUI.Layout.mapSelectionHorizontalPadding)
            .padding(.top, EdukARtUI.Layout.mapSelectionTopPadding)
            .padding(.bottom, EdukARtUI.Layout.mapSelectionBottomPadding)
        }
        .alert("Loeschen fehlgeschlagen", isPresented: deleteErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "Unbekannter Fehler")
        }
    }

    private func mapRow(for map: StoredFloorMap) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                onStartGame(map)
            } label: {
                VStack(alignment: .leading, spacing: EdukARtUI.Layout.listItemContentSpacing) {
                    Text(map.name)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("\(map.floorTiles.count) Bodenkacheln")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(EdukARtUI.Colors.brandGreen)

                    Text("AprilTag \(map.displayReferenceTagNumber)")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(EdukARtUI.Opacity.tertiaryText))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if isEditingMaps {
                Button("Loeschen", role: .destructive) {
                    delete(map)
                }
                .font(.footnote.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.86))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
        }
        .padding(EdukARtUI.Layout.listItemPadding)
        .background(Color.white.opacity(EdukARtUI.Opacity.listItemBackground))
        .clipShape(RoundedRectangle(cornerRadius: EdukARtUI.Layout.listItemCornerRadius, style: .continuous))
    }

    private var deleteErrorBinding: Binding<Bool> {
        Binding(
            get: { deleteErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    deleteErrorMessage = nil
                }
            }
        )
    }

    private func delete(_ map: StoredFloorMap) {
        do {
            try mapStore.delete(map)
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }
}

struct CompactOverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, EdukARtUI.Layout.compactButtonHorizontalPadding)
            .padding(.vertical, EdukARtUI.Layout.compactButtonVerticalPadding)
            .background(.black.opacity(configuration.isPressed ? EdukARtUI.Opacity.pressedCompactButton : EdukARtUI.Opacity.compactButton))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
