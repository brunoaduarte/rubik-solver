import SwiftUI
import AVFoundation
import UIKit

/// Shows a camera preview restricted to its container and reports detected
/// Rubik's cube colors to the shared model.
struct CameraOverlayView: UIViewRepresentable {
    @ObservedObject var cube: RubiksCubeModel

    /// Simple `UIView` subclass whose backing layer is an `AVCaptureVideoPreviewLayer`.
    /// This keeps the preview sized correctly as the view resizes.
    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: CameraOverlayView
        var session: AVCaptureSession?

        init(parent: CameraOverlayView) { self.parent = parent }

        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)

            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
                return
            }
            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

            let stepX = width / 4
            let stepY = height / 4
            let startX = width / 2 - stepX
            let startY = height / 2 - stepY

            var detected: [CubeColor] = []
            for row in 0..<3 {
                for col in 0..<3 {
                    let x = startX + col * stepX
                    let y = startY + row * stepY
                    let offset = y * bytesPerRow + x * 4
                    let b = buffer[offset]
                    let g = buffer[offset + 1]
                    let r = buffer[offset + 2]
                    let ui = UIColor(red: CGFloat(r) / 255.0,
                                      green: CGFloat(g) / 255.0,
                                      blue: CGFloat(b) / 255.0,
                                      alpha: 1.0)
                    detected.append(CubeColor.from(ui))
                }
            }

            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

            guard detected.count == 9 else { return }
            let center = detected[4]
            if let faceIndex = parent.cube.faceIndex(for: center) {
                DispatchQueue.main.async {
                    parent.cube.update(face: faceIndex, with: detected)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()

        let session = AVCaptureSession()
        context.coordinator.session = session
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(context.coordinator,
                                       queue: DispatchQueue(label: "cube-scan"))
        session.addOutput(output)

        // Configure orientation of the camera preview.
        if let connection = view.videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        let startSession = {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { startSession() }
            }
        default:
            break
        }

        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        // Nothing required – the preview layer automatically matches the view's bounds.
    }
}

