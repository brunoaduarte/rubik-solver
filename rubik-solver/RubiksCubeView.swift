import SwiftUI
import SceneKit
import UIKit

/// Displays a 3D solid Rubik's cube using SceneKit.
struct RubiksCubeView: UIViewRepresentable {
    @ObservedObject var cube: RubiksCubeModel

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = SCNScene()
        view.allowsCameraControl = true
        view.backgroundColor = .clear

        let cubeNode = SCNNode()
        cubeNode.name = "cube"
        cubeNode.geometry = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.0)
        cubeNode.geometry?.materials = cubeMaterials()
        // Start angled so front, right and top faces are visible
        cubeNode.eulerAngles = SCNVector3(-Float.pi / 6, Float.pi / 4, 0)
        view.scene?.rootNode.addChildNode(cubeNode)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 3)
        view.scene?.rootNode.addChildNode(cameraNode)

        return view
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        if let cubeNode = scnView.scene?.rootNode.childNode(withName: "cube", recursively: false),
           let box = cubeNode.geometry as? SCNBox {
            box.materials = cubeMaterials()
        }
    }

    private func cubeMaterials() -> [SCNMaterial] {
        // SCNBox expects materials in the order: front, right, back, left, top, bottom
        let order = [2, 1, 5, 4, 0, 3] // F, R, B, L, U, D
        return order.map { idx in
            let material = SCNMaterial()
            material.diffuse.contents = faceImage(from: cube.colors(for: idx))
            return material
        }
    }

    private func faceImage(from colors: [Color]) -> UIImage {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let cell = CGSize(width: size.width / 3, height: size.height / 3)
            for row in 0..<3 {
                for col in 0..<3 {
                    let idx = row * 3 + col
                    let rect = CGRect(x: CGFloat(col) * cell.width,
                                      y: CGFloat(row) * cell.height,
                                      width: cell.width,
                                      height: cell.height)
                    cg.setFillColor(UIColor(colors[idx]).cgColor)
                    cg.fill(rect)
                    cg.setStrokeColor(UIColor.black.cgColor)
                    cg.stroke(rect, width: 2)
                }
            }
        }
    }
}
