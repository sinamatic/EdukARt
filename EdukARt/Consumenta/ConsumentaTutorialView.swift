import SwiftUI
import UIKit
import PDFKit
import MessageUI

enum ConsumentaTutorialStep: Int {
    case welcome
    case connection
    case emergencyStop
}

struct ConsumentaTutorialView: View {
    let step: ConsumentaTutorialStep
    let isWifiReachable: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.86)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("Spielanleitung")
                        .font(.headline)
                    Spacer()
                    Text("\(step.rawValue + 1) / 3")
                        .monospacedDigit()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("Tutorial schließen")
                    .opacity(step == .emergencyStop ? 0 : 1)
                    .disabled(step == .emergencyStop)
                    .accessibilityHidden(step == .emergencyStop)
                }

                // Only the page content scrolls. Navigation stays at the same
                // bottom position regardless of text length or current page.
                ScrollView {
                    VStack(spacing: 24) {
                        switch step {
                        case .welcome:
                            TutorialTagsPage()
                        case .connection:
                            TutorialConnectionPage(isWifiReachable: isWifiReachable)
                        case .emergencyStop:
                            TutorialPowerPage()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .frame(maxHeight: .infinity)
                .id(step)

                HStack(spacing: 16) {
                    Button("Zurück", action: onBack)
                        .buttonStyle(.bordered)
                        .opacity(step == .welcome ? 0 : 1)
                        .disabled(step == .welcome)

                    Spacer()

                    Button("Weiter", action: onNext)
                        .buttonStyle(.borderedProminent)
                        .tint(Color("BrandGreen"))
                        .disabled(step == .emergencyStop)
                        .opacity(step == .emergencyStop ? 0 : 1)
                        .accessibilityHidden(step == .emergencyStop)
                }
                .controlSize(.large)
            }
            .padding(24)
            .frame(maxWidth: 600, maxHeight: .infinity)
            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 20)
            .padding(.top, 100)
            .padding(.bottom, 24)
        }
        .foregroundStyle(.white)
    }
}

private struct TutorialTagsPage: View {
    @State private var thumbnail: UIImage?
    @State private var presentation: PDFPresentation?
    @State private var attachment = Data()
    @State private var showsMailUnavailable = false
    @State private var errorMessage = ""
    @State private var showsError = false

    private var pdfURL: URL? {
        Bundle.main.url(forResource: "AprilTags_black96mm_0-39", withExtension: "pdf")
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("AprilTags vorbereiten")
                .font(.title2.bold())

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Vorschau der AprilTag-Druckvorlage")
            } else {
                Image(systemName: "printer.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color("BrandGreen"))
                    .accessibilityHidden(true)
            }

            Text("Drucke AprilTags aus und platziere sie im Zimmer.")
                .font(.title3)
                .multilineTextAlignment(.center)

            if let pdfURL {
                TutorialPDFPrintButton(url: pdfURL) {
                    showError($0)
                }
                .frame(height: 48)

                Button {
                    if MFMailComposeViewController.canSendMail() {
                        do {
                            attachment = try Data(contentsOf: pdfURL)
                            presentation = .mail
                        } catch {
                            showError("Die PDF konnte nicht geladen werden.")
                        }
                    } else {
                        showsMailUnavailable = true
                    }
                } label: {
                    Label("Per Mail senden", systemImage: "envelope")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
            } else {
                Text("Die AprilTag-PDF ist nicht verfügbar.")
                    .foregroundStyle(.red)
            }

            Text("Weniger als 3 m Abstand zueinander.\n\nDrucke einseitig (Duplex aus) und in tatsächlicher Größe / mit 100 % Skalierung. Nicht an die Seitengröße anpassen.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
        .task {
            if let pdfURL, let page = PDFDocument(url: pdfURL)?.page(at: 0) {
                thumbnail = page.thumbnail(of: CGSize(width: 360, height: 500), for: .mediaBox)
            }
        }
        .sheet(item: $presentation) { presentation in
            switch presentation {
            case .mail:
                TutorialPDFMailComposer(data: attachment)
            case .share:
                if let pdfURL {
                    TutorialPDFShareSheet(url: pdfURL)
                }
            }
        }
        .alert("Mail ist nicht eingerichtet", isPresented: $showsMailUnavailable) {
            Button("PDF teilen") { presentation = .share }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Richte einen Account in Apple Mail ein oder teile die PDF mit einer anderen App.")
        }
        .alert("PDF konnte nicht geöffnet werden", isPresented: $showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showsError = true
    }

    private enum PDFPresentation: String, Identifiable {
        case mail
        case share
        var id: String { rawValue }
    }
}

private struct TutorialConnectionPage: View {
    let isWifiReachable: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text("Wähle deinen Roboter")
                .font(.title2.bold())

            Image(systemName: "wifi")
                .font(.system(size: 72))
                .foregroundStyle(Color("BrandGreen"))
                .accessibilityHidden(true)

            Text("Verbinde dich mit dem WLAN von Eduard.")
                .font(.title3)
                .multilineTextAlignment(.center)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("WLAN-Einstellungen", systemImage: "wifi")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isWifiReachable ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Text("Wähle in den iOS-Einstellungen das WLAN deines Roboters.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Divider().overlay(.white.opacity(0.3))

            Text("Oder spiele mit dem AR-Roboter.")
                .font(.title3)

            HStack(spacing: 16) {
                Image(systemName: "arkit")
                    .font(.title3.bold())
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.14), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.36), lineWidth: 2))

                Image(systemName: "arrow.right")

                Label("Show AR", systemImage: "arkit")
                    .font(.headline)
                    .padding(12)
                    .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityElement(children: .combine)

            Text("Öffne nach „Start Game“ das AR-Menü über dieses Symbol und wähle „Show AR“. ")
                .font(.body)
                .multilineTextAlignment(.center)
        }
    }
}

private struct TutorialPowerPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Text("Enable / Disable Robot")
                .font(.title2.bold())

            Image(systemName: "power")
                .font(.system(size: 72, weight: .bold))
                .frame(width: 132, height: 132)
                .background(.red.opacity(0.86), in: Circle())
                .accessibilityHidden(true)

            Text("Aktiviere oder deaktiviere den Roboter über den Knopf rechts oben – auch im Notfall oder bei Verbindungsverlust.")
                .font(.title3)
                .multilineTextAlignment(.center)

            Text("Drücke den Knopf einmal, um das Tutorial zu beenden.")
                .font(.headline)
                .foregroundStyle(Color("BrandGreen"))
                .multilineTextAlignment(.center)
        }
    }
}

private struct TutorialPDFPrintButton: UIViewRepresentable {
    let url: URL
    let onError: (String) -> Void

    func makeUIView(context: Context) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = String(localized: "Drucken")
        configuration.image = UIImage(systemName: "printer")
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = UIColor(named: "BrandGreen")
        let button = UIButton(configuration: configuration)
        button.addAction(UIAction { [weak button] _ in
            guard let button else { return }
            guard UIPrintInteractionController.isPrintingAvailable,
                  UIPrintInteractionController.canPrint(url) else {
                onError("Diese PDF kann auf diesem Gerät nicht gedruckt werden.")
                return
            }

            let printer = UIPrintInteractionController.shared
            let info = UIPrintInfo(dictionary: nil)
            info.jobName = "AprilTags 0–39"
            info.outputType = .general
            info.duplex = .none
            printer.printInfo = info
            printer.printingItem = url
            let presented = printer.present(from: button.bounds, in: button, animated: true) { _, _, error in
                if let error { onError(error.localizedDescription) }
            }
            if !presented {
                onError("Der Druckdialog konnte nicht geöffnet werden.")
            }
        }, for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}

private struct TutorialPDFMailComposer: UIViewControllerRepresentable {
    let data: Data

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject("EdukARt – AprilTags zum Ausdrucken")
        composer.setMessageBody("Im Anhang findest du die AprilTags für EdukARt.", isHTML: false)
        composer.addAttachmentData(data, mimeType: "application/pdf", fileName: "AprilTags_black96mm_0-39.pdf")
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

private struct TutorialPDFShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
