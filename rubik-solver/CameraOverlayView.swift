import SwiftUI
import AVFoundation

/// Shows camera preview restricted to its container with a wireframe cube overlay
/// to guide the user while scanning.
struct CameraOverlayView: UIViewRepresentable {
    @ObservedObject var cube: RubiksCubeModel

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: CameraOverlayView
        var session: AVCaptureSession?
        init(parent: CameraOverlayView) { self.parent = parent }
        // Placeholder for future color detection logic
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        let session = AVCaptureSession()
        context.coordinator.session = session
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }
        session.addInput(input)

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        let overlay = CubeWireframeView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .clear
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        view.layer.sublayers?.first?.frame = view.bounds
    }
}

/// Simple wireframe cube drawing used as overlay for guidance.
class CubeWireframeView: UIView {
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(2)

        let w = rect.width
        let h = rect.height
        let size = min(w, h) * 0.5
        let offsetX = (w - size) / 2
        let offsetY = (h - size) / 2
        let depth = size * 0.3

        // Front face
        let front = CGRect(x: offsetX, y: offsetY, width: size, height: size)
        ctx.stroke(front)
        // Back face
        let back = CGRect(x: offsetX + depth, y: offsetY + depth, width: size, height: size)
        ctx.stroke(back)

        // Connect corners
        ctx.move(to: CGPoint(x: front.minX, y: front.minY))
        ctx.addLine(to: CGPoint(x: back.minX, y: back.minY))
        ctx.move(to: CGPoint(x: front.maxX, y: front.minY))
        ctx.addLine(to: CGPoint(x: back.maxX, y: back.minY))
        ctx.move(to: CGPoint(x: front.minX, y: front.maxY))
        ctx.addLine(to: CGPoint(x: back.minX, y: back.maxY))
        ctx.move(to: CGPoint(x: front.maxX, y: front.maxY))
        ctx.addLine(to: CGPoint(x: back.maxX, y: back.maxY))
        ctx.strokePath()

        drawGrid(in: front, context: ctx)
        drawGrid(in: back, context: ctx)
    }

    private func drawGrid(in rect: CGRect, context ctx: CGContext) {
        let thirdW = rect.width / 3
        let thirdH = rect.height / 3
        for i in 1..<3 {
            ctx.move(to: CGPoint(x: rect.minX + CGFloat(i) * thirdW, y: rect.minY))
            ctx.addLine(to: CGPoint(x: rect.minX + CGFloat(i) * thirdW, y: rect.maxY))
        }
        for i in 1..<3 {
            ctx.move(to: CGPoint(x: rect.minX, y: rect.minY + CGFloat(i) * thirdH))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + CGFloat(i) * thirdH))
        }
        ctx.strokePath()
    }
}
