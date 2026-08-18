import SwiftUI

@main
struct Chess3DApp: App {
    var body: some Scene {
        WindowGroup {
            ChessRootView()
        }
    }
}

struct ChessRootView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("♚ Chess 3D (Unreal Engine 5)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Metal Forward Rendering • 60 FPS • Chaos Physics")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
}
