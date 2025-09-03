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

    /// Color classification using HSV ranges rather than raw RGB distance.
    /// HSV allows more robust separation of Rubik's cube colors under
    /// different lighting conditions.
    static func from(_ color: UIColor) -> CubeColor {
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &v, alpha: &a)

        // Treat low-brightness samples as unknown/gray.
        guard v > 0.2 else { return .gray }

        // Whites have very low saturation but remain bright.
        if s < 0.2 && v > 0.8 { return .white }

        switch h {
        case 0.0..<0.05, 0.95...1.0:
            return .red
        case 0.05..<0.13:
            return .orange
        case 0.13..<0.20:
            return .yellow
        case 0.20..<0.45:
            return .green
        case 0.45..<0.75:
            return .blue
        default:
            return .gray
        }
    }
}

