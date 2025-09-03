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
        private let historyLength = 5
        private var recentDetections: [[CubeColor]] = []

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

            // Average a square patch of pixels for each sticker instead of
            // sampling a single point. This greatly improves color accuracy.
            let sampleSize = max(2, min(stepX, stepY) / 6)

            var detected: [CubeColor] = []
            for row in 0..<3 {
                for col in 0..<3 {
                    let centerX = startX + col * stepX
                    let centerY = startY + row * stepY

                    var rTotal = 0
                    var gTotal = 0
                    var bTotal = 0
                    var count = 0

                    let originX = max(0, centerX - sampleSize / 2)
                    let originY = max(0, centerY - sampleSize / 2)

                    for yy in 0..<sampleSize {
                        for xx in 0..<sampleSize {
                            let x = originX + xx
                            let y = originY + yy
                            if x < width && y < height {
                                let idx = y * bytesPerRow + x * 4
                                bTotal += Int(buffer[idx])
                                gTotal += Int(buffer[idx + 1])
                                rTotal += Int(buffer[idx + 2])
                                count += 1
                            }
                        }
                    }

                    guard count > 0 else { continue }
                    let r = CGFloat(rTotal) / CGFloat(count) / 255.0
                    let g = CGFloat(gTotal) / CGFloat(count) / 255.0
                    let b = CGFloat(bTotal) / CGFloat(count) / 255.0
                    let ui = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                    detected.append(CubeColor.from(ui))
                }
            }

            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

            guard detected.count == 9 else { return }

            recentDetections.append(detected)
            if recentDetections.count > historyLength { recentDetections.removeFirst() }
            guard recentDetections.count == historyLength else { return }

            var stable: [CubeColor] = []
            for idx in 0..<9 {
                var tally: [CubeColor: Int] = [:]
                for sample in recentDetections {
                    tally[sample[idx], default: 0] += 1
                }
                if let (color, count) = tally.max(by: { $0.value < $1.value }),
                   count == historyLength, color != .gray {
                    stable.append(color)
                } else {
                    return
                }
            }

            let center = stable[4]
            if let faceIndex = parent.cube.faceIndex(for: center) {
                if parent.cube.faces[faceIndex] != stable {
                    DispatchQueue.main.async {
                        parent.cube.update(face: faceIndex, with: stable)
                    }
                }
            }

            recentDetections.removeAll()
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

