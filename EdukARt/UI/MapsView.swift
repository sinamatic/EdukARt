//
//  MapsView.swift
//  EdukARt
//
//

import SwiftUI

struct MapsView: View {
    @ObservedObject var mapStore: MapStore
    @State private var selectedMap: StoredFloorMap?
    let onClose: () -> Void

    var body: some View {
        Group {
            if let selectedMap {
                MapPreviewView(map: selectedMap) {
                    self.selectedMap = nil
                }
            } else {
                listView
            }
        }
    }

    private var listView: some View {
        ZStack {
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Button("Zurueck") {
                        onClose()
                    }
                    .buttonStyle(MapOverlayButtonStyle())

                    Spacer()
                }

                Text("Karten")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                if mapStore.maps.isEmpty {
                    Text("Noch keine Karten gespeichert.")
                        .foregroundStyle(.white.opacity(0.82))
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(mapStore.maps) { map in
                                Button {
                                    selectedMap = map
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(map.name)
                                            .font(.headline)
                                        Text(map.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.footnote)
                                            .foregroundStyle(.white.opacity(0.78))
                                        Text(String(format: "%.1f m²", map.minimumAreaSquareMeters))
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.green)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(18)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct MapOverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.65))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
