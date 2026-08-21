//
//  CameraPreviewView.swift
//  EdukARt-Rebuild
//
//  Created by Sina Steinmüller on 21.08.26.
//  Source Codex + Apple Documentation
//  Apple – AVCaptureVideoPreviewLayer
//  Apple – AVCaptureSession
//  Apple – UIViewRepresentable
//  Apple – NSCameraUsageDescription


import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {

    func makeUIView(context: Context) -> CameraUIView {
        CameraUIView()
    }

    func updateUIView(
        _ uiView: CameraUIView,
        context: Context
    ) {
    }
}

final class CameraUIView: UIView {

    private let session = AVCaptureSession()

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.session = session

        startCamera()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func startCamera() {

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)

            if session.canAddInput(input) {
                session.addInput(input)
            }

            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }

        } catch {
            print("Camera error:", error)
        }
    }
}
