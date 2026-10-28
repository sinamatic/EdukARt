import SwiftUI

struct ConsumentaGhostReplayView: View {
    let phase: ConsumentaGhostReplayController.Phase
    let referenceTagID: Int
    let onStart: () -> Void
    let onReplay: () -> Void
    let onClose: () -> Void

    var body: some View {
        if phase != .inactive {
            VStack(spacing: 16) {
                content
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(.black.opacity(0.84))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .inactive:
            EmptyView()

        case .awaitingReference:
            ProgressView()
                .tint(.white)

            Text("Return to the start")
                .font(.title2.bold())

            Text("Point the camera at reference AprilTag #\(referenceTagID). The Ghost Drive can start as soon as the course is localized again.")
                .multilineTextAlignment(.center)

        case .ready:
            Text("Ghost Drive Ready")
                .font(.title2.bold())

            Text("Stay at the start and keep the course in view.")
                .multilineTextAlignment(.center)

            Button("Start Ghost Drive", action: onStart)
                .buttonStyle(.borderedProminent)
                .tint(Color("BrandGreen"))

        case .playing:
            ProgressView()
                .tint(.white)

            Text("Ghost Drive")
                .font(.title2.bold())

            Text("The AR Eduard is replaying the saved drive.")
                .multilineTextAlignment(.center)

        case .finished:
            Text("Ghost Drive Finished")
                .font(.title2.bold())

            Button("Show Ghost Race Again", action: onReplay)
                .buttonStyle(.borderedProminent)
                .tint(Color("BrandGreen"))

            Button("Back to Game", action: onClose)
                .buttonStyle(.bordered)
                .tint(.white)

        case .failed:
            Text("Ghost Drive could not be loaded.")
                .font(.headline)
                .multilineTextAlignment(.center)

            Button("Close", action: onClose)
                .buttonStyle(.bordered)
                .tint(.white)
        }
    }
}
