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

    /// UIKit color for drawing overlays and SceneKit materials.
    var uiColor: UIColor {
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

    /// Human‑readable name used in debug overlays.
    var label: String {
        switch self {
        case .white:  return "WHITE"
        case .yellow: return "YELLOW"
        case .red:    return "RED"
        case .orange: return "ORANGE"
        case .blue:   return "BLUE"
        case .green:  return "GREEN"
        case .gray:   return "?"
        }
    }

    /// Reference HSV values for each cube color computed from standard sRGB
    /// swatches. These values are used to classify camera samples by weighted
    /// HSV distance, mirroring the approach in the Python prototype.
    private static let referenceHSV: [CubeColor: (h: CGFloat, s: CGFloat, v: CGFloat)] = {
        func hsv(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
            let color = UIColor(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: 1.0)
            var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
            return (h, s, v)
        }
        return [
            .white:  hsv(255, 255, 255),
            .yellow: hsv(255, 213,   0),
            .orange: hsv(255, 146,   0),
            .red:    hsv(183,  18,  52),
            .green:  hsv(  0, 155,  72),
            .blue:   hsv(  0,  70, 173)
        ]
    }()

    private static let hWeight: CGFloat = 2.0
    private static let sWeight: CGFloat = 1.0
    private static let vWeight: CGFloat = 1.0

    /// Classify a sampled color by comparing its HSV components against the
    /// reference palette. The nearest color wins; samples that are too dark are
    /// treated as unknown/gray.
    static func from(h: CGFloat, s: CGFloat, v: CGFloat) -> CubeColor {
        guard v > 0.1 else { return .gray }

        var best: CubeColor = .gray
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for (cubeColor, ref) in referenceHSV {
            let dH = min(abs(h - ref.h), 1 - abs(h - ref.h)) * hWeight
            let dS = abs(s - ref.s) * sWeight
            let dV = abs(v - ref.v) * vWeight
            let dist = dH + dS + dV
            if dist < bestDistance {
                bestDistance = dist
                best = cubeColor
            }
        }

        // If the closest reference is still far away, mark as gray to avoid
        // propagating wildly incorrect colors.
        return bestDistance > 0.6 ? .gray : best
    }

    /// Convenience wrapper for callers providing a `UIColor` sample.
    static func from(_ color: UIColor) -> CubeColor {
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
        return from(h: h, s: s, v: v)
    }
}

