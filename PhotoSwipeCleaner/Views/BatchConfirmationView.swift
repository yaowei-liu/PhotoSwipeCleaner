import SwiftUI
import Photos

struct BatchConfirmationView: View {
    @EnvironmentObject var viewModel: PhotoSwipeViewModel
    @Environment(\.dismiss) var dismiss
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Review Deletions")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("\(viewModel.pendingDeletions.count) photos marked for deletion")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                            ForEach(viewModel.pendingDeletions) { photo in
                                ThumbnailView(photo: photo)
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Button {
                            onConfirm()
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete \(viewModel.pendingDeletions.count) Photos")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                        
                        Button {
                            onCancel()
                        } label: {
                            Text("Keep All")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct ThumbnailView: View {
    let photo: Photo
    @State private var uiImage: UIImage?
    
    var body: some View {
        ZStack {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    )
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isSynchronous = false
        
        let targetSize = CGSize(width: 160, height: 160)
        
        manager.requestImage(for: photo.asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
            DispatchQueue.main.async {
                self.uiImage = image
            }
        }
    }
}