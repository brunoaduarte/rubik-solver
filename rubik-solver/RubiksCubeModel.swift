import SwiftUI

/// Data model representing colors for each sticker of a Rubik's Cube.
/// Each face has 9 colors stored in row-major order.
class RubiksCubeModel: ObservableObject {
    /// Six faces, each with nine `Color` values.
    @Published var faces: [[Color]]

    init() {
        let base: [Color] = [.white, .yellow, .red, .orange, .blue, .green]
        self.faces = base.map { faceColor in Array(repeating: faceColor, count: 9) }
    }
}
