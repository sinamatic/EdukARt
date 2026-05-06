//
//  MapsView.swift
//  EdukARt
//
//

import SwiftUI

struct MapsView: View {
    @ObservedObject var mapStore: MapStore
    @State private var selectedMap: StoredFloorMap?
    @State private var deleteErrorMessage: String?
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
        .alert("Loeschen fehlgeschlagen", isPresented: deleteErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "Unbekannter Fehler")
        }
    }

    private var listView: some View {
        ZStack {
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.84)
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
                    List {
                        ForEach(mapStore.maps) { map in
                            Button {
                                selectedMap = map
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(map.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    Text(String(format: "%.1f m²", map.minimumAreaSquareMeters))
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.green)

                                    detailRow(title: "Aufgenommen am", value: map.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    detailRow(title: "Um", value: map.createdAt.formatted(date: .omitted, time: .shortened))
                                    detailRow(title: "Speichergroesse", value: ByteCountFormatter.string(fromByteCount: Int64(mapStore.estimatedStorageSize(for: map)), countStyle: .file))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Loeschen", role: .destructive) {
                                    delete(map)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)
            .padding(.bottom, 24)
        }
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
            if selectedMap?.id == map.id {
                selectedMap = nil
            }
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.74))

            Spacer(minLength: 12)

            Text(value)
                .font(.footnote)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

private struct MapOverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(0.65))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
