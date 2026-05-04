//
//  CreateMapView.swift
//  EdukARt
//
//

import Foundation
import SwiftUI

struct CreateMapView: View {
    @StateObject private var mapScanSession = MapScanSession()
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
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button("Zurueck") {
                onClose()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.65))
            .foregroundStyle(.white)
            .clipShape(Capsule())

            Spacer(minLength: 12)

            Text(mapScanSession.statusText)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.black.opacity(0.65))
                .foregroundStyle(.white)
                .clipShape(Capsule())
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

                switch mapScanSession.phase {
                case .wallScan:
                    wallScanContent
                case .floorScan, .readyToSave:
                    floorScanContent
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
        .frame(maxWidth: .infinity, maxHeight: 340, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var wallScanContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusRow(
                title: "Wandflaeche",
                value: String(format: "%.1f m²", mapScanSession.scannedWallArea)
            )

            statusRow(
                title: "Geschaetzte Raumflaeche",
                value: String(format: "%.1f m²", mapScanSession.estimatedRoomArea)
            )

            statusRow(
                title: "Rundum erfasst",
                value: "\(Int(mapScanSession.wallCoverageProgress * 100))%"
            )

            ProgressView(value: mapScanSession.wallCoverageProgress)
                .tint(.green)

            Text(mapScanSession.canContinueToFloorScan ? "Die Waende sind ausreichend erfasst. Du kannst jetzt in den Bodenscan wechseln." : "Bewege dich einmal rundum und richte die Kamera weiter auf Waende und Raumgrenzen, bis der Raum stabil erfasst ist.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white.opacity(0.82))

            Button("Weiter zum Bodenscan") {
                mapScanSession.continueToFloorScan()
            }
            .buttonStyle(PrimaryScanButtonStyle())
            .disabled(mapScanSession.canContinueToFloorScan == false)
            .opacity(mapScanSession.canContinueToFloorScan ? 1 : 0.55)
        }
    }

    private var floorScanContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusRow(
                title: "Bodenflaeche bestaetigt",
                value: String(format: "%.1f m²", mapScanSession.confirmedFloorArea)
            )

            statusRow(
                title: "Raumziel",
                value: String(format: "%.1f m²", mapScanSession.estimatedRoomArea)
            )

            statusRow(
                title: "Bodenabdeckung",
                value: "\(Int(mapScanSession.floorCoverageProgress * 100))%"
            )

            if let lowestFloorHeight = mapScanSession.lowestFloorHeight {
                statusRow(
                    title: "Tiefster Boden",
                    value: String(format: "%.2f m", lowestFloorHeight)
                )
            }

            ProgressView(value: mapScanSession.floorCoverageProgress)
                .tint(.green)

            Text(mapScanSession.canSaveMap ? "Der dunkel eingefaerbte Boden ist weitgehend vollstaendig. Wenn die Flaeche stimmt, kannst du speichern." : "Nur die tiefste Flaeche wird als echter Boden gezaehlt. Scanne alle freien Bodenbereiche, bis die dunkle Flaeche den Raum abdeckt.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white.opacity(0.82))

            if mapScanSession.canSaveMap {
                Button("Karte speichern") {
                    mapScanSession.showSavePlaceholder()
                }
                .buttonStyle(PrimaryScanButtonStyle())
            }
        }
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
