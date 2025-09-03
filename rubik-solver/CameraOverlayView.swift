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

                    var hX: CGFloat = 0
                    var hY: CGFloat = 0
                    var sTotal: CGFloat = 0
                    var vTotal: CGFloat = 0
                    var count: CGFloat = 0

                    let originX = max(0, centerX - sampleSize / 2)
                    let originY = max(0, centerY - sampleSize / 2)

                    for yy in 0..<sampleSize {
                        for xx in 0..<sampleSize {
                            let x = originX + xx
                            let y = originY + yy
                            if x < width && y < height {
                                let idx = y * bytesPerRow + x * 4
                                let b = CGFloat(buffer[idx]) / 255.0
                                let g = CGFloat(buffer[idx + 1]) / 255.0
                                let r = CGFloat(buffer[idx + 2]) / 255.0
                                var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
                                UIColor(red: r, green: g, blue: b, alpha: 1.0)
                                    .getHue(&h, saturation: &s, brightness: &v, alpha: &a)
                                hX += cos(h * 2 * CGFloat.pi)
                                hY += sin(h * 2 * CGFloat.pi)
                                sTotal += s
                                vTotal += v
                                count += 1
                            }
                        }
                    }

                    guard count > 0 else { continue }
                    var meanHue = atan2(hY / count, hX / count) / (2 * CGFloat.pi)
                    if meanHue < 0 { meanHue += 1 }
                    let meanSat = sTotal / count
                    let meanVal = vTotal / count
                    detected.append(CubeColor.from(h: meanHue, s: meanSat, v: meanVal))
                }
            }

            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

            guard detected.count == 9 else { return }

            recentDetections.append(detected)
            if recentDetections.count > historyLength { recentDetections.removeFirst() }
            guard recentDetections.count == historyLength else { return }

            var stable: [CubeColor] = []
            let required = historyLength - 1
            for idx in 0..<9 {
                var tally: [CubeColor: Int] = [:]
                for sample in recentDetections {
                    tally[sample[idx], default: 0] += 1
                }
                if let (color, count) = tally.max(by: { $0.value < $1.value }),
                   count >= required, color != .gray {
                    stable.append(color)
                } else {
                    return
                }
            }

            let center = stable[4]
            if let faceIndex = parent.cube.faceIndex(for: center) {
                if parent.cube.faces[faceIndex] != stable {
                    DispatchQueue.main.async { [weak self] in
                        self?.parent.cube.update(face: faceIndex, with: stable)
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
        if let connection = view.videoPreviewLayer.connection {
            if #available(iOS 17, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
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

