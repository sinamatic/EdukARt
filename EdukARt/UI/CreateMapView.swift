//
//  CreateMapView.swift
//  EdukARt
//
//

import Foundation
import SwiftUI

struct CreateMapView: View {
    @ObservedObject var mapStore: MapStore
    @StateObject private var mapScanSession = MapScanSession()
    @State private var mapName = ""
    let onClose: () -> Void

    var body: some View {
        ZStack {
            MapScanViewContainer(session: mapScanSession)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.72), .clear, .black.opacity(0.84)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 12)
                footerCard
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button("Zurueck") {
                onClose()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(0.65))
            .foregroundStyle(.white)
            .clipShape(Capsule())

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                statusPill(mapScanSession.statusText)
                statusPill(mapScanSession.originStatusText)
            }
        }
    }

    private var footerCard: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text(mapScanSession.titleText)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(mapScanSession.instructionText)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.white.opacity(0.92))

                statusRow(
                    title: "Bodenflaeche bestaetigt",
                    value: String(format: "%.1f m²", mapScanSession.confirmedFloorArea)
                )

                statusRow(
                    title: "Mindestflaeche",
                    value: String(format: "%.1f m²", mapScanSession.minimumRequiredAreaSquareMeters)
                )

                statusRow(
                    title: "Fortschritt",
                    value: "\(Int(mapScanSession.floorProgress * 100))%"
                )

                if let lowestFloorHeight = mapScanSession.lowestFloorHeight {
                    statusRow(
                        title: "Tiefster Boden",
                        value: String(format: "%.2f m", lowestFloorHeight)
                    )
                }

                statusRow(
                    title: "Startpunkt",
                    value: mapScanSession.hasOrigin ? "gesetzt" : "noch nicht gesetzt"
                )

                ProgressView(value: mapScanSession.floorProgress)
                    .tint(.green)

                if mapScanSession.hasOrigin == false {
                    Button("Startpunkt setzen") {
                        mapScanSession.requestOriginPlacement()
                    }
                    .buttonStyle(PrimaryScanButtonStyle())
                }

                if mapScanSession.canFinishScan {
                    Button("Fertig") {
                        mapScanSession.finishScan()
                    }
                    .buttonStyle(PrimaryScanButtonStyle())
                }

                if mapScanSession.isReviewingScan {
                    TextField("Kartenname", text: $mapName)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.14))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button(mapScanSession.saveButtonTitle) {
                        mapScanSession.saveMap(named: mapName, into: mapStore)
                    }
                    .buttonStyle(PrimaryScanButtonStyle())
                    .disabled(mapScanSession.canSaveMap == false)
                    .opacity(mapScanSession.canSaveMap || mapScanSession.isSaving || mapScanSession.hasSavedCurrentScan ? 1 : 0.55)
                }

                if let saveMessage = mapScanSession.saveMessage {
                    Text(saveMessage)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: 360, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.white)
        }
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(0.65))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}

private struct PrimaryScanButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.green.opacity(configuration.isPressed ? 0.78 : 0.92))
            )
            .foregroundStyle(.black)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
