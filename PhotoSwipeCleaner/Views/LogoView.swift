import SwiftUI

struct LogoView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: .purple.opacity(0.5), radius: 20, x: 0, y: 10)
            
            VStack(spacing: 8) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

struct AppLogo_Previews: PreviewProvider {
    static var previews: some View {
        LogoView()
            .previewLayout(.sizeThatFits)
    }
}