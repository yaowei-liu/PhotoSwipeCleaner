import SwiftUI
import Photos

struct PhotoCard: View {
    let photo: Photo
    @Binding var dragAmount: CGSize
    @Binding var swipeDirection: PhotoSwipeView.SwipeDirection
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    
    private let swipeThreshold: CGFloat = 100
    @State private var uiImage: UIImage?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .foregroundColor(.white)
            }
            
            swipeOverlay
        }
        .cornerRadius(20)
        .offset(x: dragAmount.width)
        .rotationEffect(.degrees(dragAmount.width / 15.0))
        .scaleEffect(1.0 - min(abs(dragAmount.width) / 800.0, 0.2))
        .opacity(1.0 - min(abs(dragAmount.width) / 250.0, 0.5))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: dragAmount)
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
        .onAppear {
            loadImage()
        }
    }
    
    @ViewBuilder
    private var swipeOverlay: some View {
        ZStack {
            if dragAmount.width < -swipeThreshold {
                Color.red.opacity(0.3)
                    .overlay(
                        VStack {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                            Text("DELETE")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    )
            } else if dragAmount.width > swipeThreshold {
                Color.green.opacity(0.3)
                    .overlay(
                        VStack {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                            Text("KEEP")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: dragAmount.width)
    }
    
    private func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        let targetSize = CGSize(width: 400, height: 600)
        
        manager.requestImage(for: photo.asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
            DispatchQueue.main.async {
                self.uiImage = image
            }
        }
    }
}