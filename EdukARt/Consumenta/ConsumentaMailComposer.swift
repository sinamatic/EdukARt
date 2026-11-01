import MessageUI
import SwiftUI

struct ConsumentaDriveSharingView: View {
    let recordingURL: URL

    @Environment(\.openURL) private var openURL
    @State private var isShowingMailComposer = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Teile deine gefahrene Strecke per Mail, um sie am Bildschirm anzeigen zu lassen.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Button {
                openMail()
            } label: {
                Label("Ghost-Fahrt per Mail senden", systemImage: "envelope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("BrandGreen"))

            ShareLink(item: recordingURL) {
                Label("Anders teilen", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .sheet(isPresented: $isShowingMailComposer) {
            ConsumentaMailComposer(recordingURL: recordingURL)
        }
    }

    private func openMail() {
        if MFMailComposeViewController.canSendMail() {
            isShowingMailComposer = true
            return
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = ""
        components.queryItems = [
            URLQueryItem(
                name: "subject",
                value: "EdukARt Ghost at Consumenta"
            )
        ]

        if let url = components.url {
            openURL(url)
        }
    }
}

private struct ConsumentaMailComposer: UIViewControllerRepresentable {
    let recordingURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(nil)
        composer.setSubject("EdukARt Ghost at Consumenta")
        composer.setMessageBody(
            "Hallo Sina,\n\nim Anhang findest du meine Ghost Fahrt von der Consumenta.\n",
            isHTML: false
        )

        if let data = try? Data(contentsOf: recordingURL) {
            composer.addAttachmentData(
                data,
                mimeType: "application/json",
                fileName: recordingURL.lastPathComponent
            )
        }

        return composer
    }

    func updateUIViewController(
        _ uiViewController: MFMailComposeViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
        }
    }
}
