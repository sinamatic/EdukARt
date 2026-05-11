//
//  CreateMapView.swift
//  EdukARt
//
//

import Foundation
import SwiftUI

struct CreateMapView: View {
    private enum Mode {
        case selection
        case scanSurrounding
        case searchAprilTag
    }

    @ObservedObject var mapStore: MapStore
    @StateObject private var mapScanSession = MapScanSession()
    @StateObject private var aprilTagSearchSession = AprilTagSearchSession()
    @State private var mode: Mode = .selection
    @State private var mapName = ""
    let onClose: () -> Void

    var body: some View {
        ZStack {
            if mode == .scanSurrounding {
                MapScanViewContainer(session: mapScanSession)
                    .ignoresSafeArea()
            } else if mode == .searchAprilTag {
                AprilTagSearchViewContainer(session: aprilTagSearchSession)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }

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
                if mode == .selection {
                    onClose()
                } else {
                    mode = .selection
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(0.65))
            .foregroundStyle(.white)
            .clipShape(Capsule())

            Spacer(minLength: 12)

            if mode == .scanSurrounding {
                VStack(alignment: .trailing, spacing: 8) {
                    statusPill(mapScanSession.statusText)
                    statusPill(mapScanSession.originStatusText)
                }
            } else if mode == .searchAprilTag {
                statusPill(aprilTagSearchSession.statusText)
            }
        }
    }

    private var footerCard: some View {
        Group {
            switch mode {
            case .selection:
                selectionCard
            case .scanSurrounding:
                scanCard
            case .searchAprilTag:
                aprilTagCard
            }
        }
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Create Map")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("Waehle zuerst, wie du die Karte starten moechtest.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.92))

            Button("Scan Surrounding") {
                mode = .scanSurrounding
            }
            .buttonStyle(PrimaryScanButtonStyle())

            Button("Search April Tag") {
                mode = .searchAprilTag
            }
            .buttonStyle(SecondaryScanButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var aprilTagCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(aprilTagSearchSession.titleText)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(aprilTagSearchSession.instructionText)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white.opacity(0.92))

            if aprilTagSearchSession.detectedTagNames.isEmpty == false, aprilTagSearchSession.isTagTracked {
                statusRow(
                    title: "Erkannte Tags",
                    value: aprilTagSearchSession.detectedTagNumbersText
                )
            }

            statusRow(
                title: "Status",
                value: aprilTagSearchSession.statusText
            )

            Button("Zur Auswahl zurueck") {
                mode = .selection
            }
            .buttonStyle(PrimaryScanButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var scanCard: some View {
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

private struct SecondaryScanButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
