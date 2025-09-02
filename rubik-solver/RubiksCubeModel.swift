import SwiftUI

/// Data model representing colors for each sticker of a Rubik's Cube.
/// Each face has 9 colors stored in row-major order.
class RubiksCubeModel: ObservableObject {
    /// Six faces, each with nine `Color` values.
    @Published var faces: [[Color]]

    init() {
        let emptyFace = Array(repeating: Color.gray, count: 9)
        self.faces = Array(repeating: emptyFace, count: 6)
    }
}
