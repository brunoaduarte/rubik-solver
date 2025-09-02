import SwiftUI

/// Main layout splitting the screen between a virtual cube and the camera capture.
struct ContentView: View {
    @StateObject private var cubeModel = RubiksCubeModel()

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                RubiksCubeView(cube: cubeModel)
                    .frame(height: geo.size.height / 2)
                CameraOverlayView(cube: cubeModel)
                    .frame(height: geo.size.height / 2)
                    .clipped()
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
}

#Preview {
    ContentView()
}
