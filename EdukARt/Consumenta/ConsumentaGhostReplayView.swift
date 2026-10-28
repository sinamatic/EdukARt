import SwiftUI

struct ConsumentaGhostReplayView: View {
    let phase: ConsumentaGhostReplayController.Phase
    let referenceTagID: Int
    let onStart: () -> Void
    let onReplay: () -> Void
    let onClose: () -> Void

    var body: some View {
        if phase != .inactive {
            VStack {
                Spacer()

                VStack(spacing: 10) {
                    HStack {
                        Label("Ghost Mode", systemImage: "car.side.fill")
                            .font(.headline)

                        Spacer()

                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.headline.bold())
                                .frame(width: 32, height: 32)
                                .background(.white.opacity(0.14))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close Ghost Mode")
                    }

                    content
                }
                .padding(16)
                .frame(maxWidth: 380)
                .background(.black.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.5), lineWidth: 1.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 18)
            .padding(.bottom, 20)
            .foregroundStyle(.white)
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
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                Text("The AR Eduard is replaying the saved drive.")
                    .font(.subheadline)
            }

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
