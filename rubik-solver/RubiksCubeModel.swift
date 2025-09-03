import SwiftUI
import UIKit

/// Represents the six faces of a Rubik's Cube and their sticker colors.
class RubiksCubeModel: ObservableObject {
    /// Six faces, each with nine `CubeColor` values stored in row-major order.
    @Published var faces: [[CubeColor]]

    init() {
        let emptyFace = Array(repeating: CubeColor.gray, count: 9)
        self.faces = Array(repeating: emptyFace, count: 6)
    }

    /// Update a face with detected colors.
    func update(face: Int, with colors: [CubeColor]) {
        guard face >= 0 && face < faces.count, colors.count == 9 else { return }
        faces[face] = colors
    }

    /// Determine which cube face corresponds to the given center color.
    func faceIndex(for center: CubeColor) -> Int? {
        switch center {
        case .green:  return 2 // F
        case .red:    return 1 // R
        case .blue:   return 5 // B
        case .white:  return 0 // U
        case .yellow: return 3 // D
        case .orange: return 4 // L
        default:      return nil
        }
    }

    /// Convenience accessor returning SwiftUI colors for a face.
    func colors(for face: Int) -> [Color] {
        faces[face].map { $0.swiftUIColor }
    }
}

/// Enumeration of standard Rubik's cube colors plus a neutral gray.
enum CubeColor: CaseIterable {
    case white, yellow, red, orange, blue, green, gray

    var swiftUIColor: Color {
        switch self {
        case .white:  return .white
        case .yellow: return .yellow
        case .red:    return .red
        case .orange: return .orange
        case .blue:   return .blue
        case .green:  return .green
        case .gray:   return .gray
        }
    }

    /// Simple nearest-color classifier based on RGB distance.
    static func from(_ color: UIColor) -> CubeColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let reference: [(CubeColor, (CGFloat, CGFloat, CGFloat))] = [
            (.white,  (1, 1, 1)),
            (.yellow, (1, 1, 0)),
            (.red,    (1, 0, 0)),
            (.orange, (1, 0.5, 0)),
            (.blue,   (0, 0, 1)),
            (.green,  (0, 1, 0))
        ]

        var best: CubeColor = .gray
        var bestDist = CGFloat.greatestFiniteMagnitude
        for (cubeColor, ref) in reference {
            let dr = r - ref.0
            let dg = g - ref.1
            let db = b - ref.2
            let dist = dr*dr + dg*dg + db*db
            if dist < bestDist {
                bestDist = dist
                best = cubeColor
            }
        }
        return best
    }
}

