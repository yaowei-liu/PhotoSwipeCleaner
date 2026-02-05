import SwiftUI

struct PhotoSwipeView: View {
    @EnvironmentObject var viewModel: PhotoSwipeViewModel
    @State private var dragAmount = CGSize.zero
    @State private var swipeDirection: PhotoSwipeView.SwipeDirection = .none
    @State private var showingBatchConfirmation = false
    @State private var showingPhotoDetail: Photo?
    
    enum SwipeDirection {
        case none, left, right
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.photos.isEmpty {
                    ProgressView("Loading photos...")
                        .foregroundColor(.white)
                        .scaleEffect(1.5)
                } else if let photo = viewModel.currentPhoto {
                    photoCardView(photo: photo)
                } else if viewModel.showingCompletion {
                    CompletionView()
                } else if !viewModel.photos.isEmpty {
                    Text("No more photos")
                        .foregroundColor(.white)
                } else {
                    ProgressView("Loading...")
                        .foregroundColor(.white)
                }
            }
            .navigationTitle("Photo Cleaner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    VStack(alignment: .trailing) {
                        Text(viewModel.progressText)
                            .foregroundColor(.white)
                            .font(.caption)
                        Text(viewModel.remainingText)
                            .foregroundColor(.gray)
                            .font(.caption2)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.requestPermissionAndLoadPhotos()
            }
        }
        .fullScreenCover(isPresented: $showingBatchConfirmation) {
            BatchConfirmationView(
                onConfirm: {
                    showingBatchConfirmation = false
                    Task {
                        await viewModel.confirmBatchDelete()
                    }
                },
                onCancel: {
                    showingBatchConfirmation = false
                    viewModel.cancelBatchDelete()
                }
            )
        }
        .sheet(item: $showingPhotoDetail) { photo in
            PhotoDetailView(photo: photo)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragAmount = value.translation
                    if value.translation.width > 50 {
                        swipeDirection = .right
                    } else if value.translation.width < -50 {
                        swipeDirection = .left
                    } else {
                        swipeDirection = .none
                    }
                }
                .onEnded { value in
                    let threshold: CGFloat = 100
                    
                    if value.translation.width > threshold {
                        handleSwipeRight()
                    } else if value.translation.width < -threshold {
                        handleSwipeLeft()
                    } else {
                        resetSwipe()
                    }
                }
        )
    }
    
    @ViewBuilder
    private func photoCardView(photo: Photo) -> some View {
        ZStack {
            Color.black
            
            PhotoCard(
                photo: photo,
                dragAmount: $dragAmount,
                swipeDirection: $swipeDirection,
                onSwipeLeft: {
                    handleSwipeLeft()
                },
                onSwipeRight: {
                    handleSwipeRight()
                }
            )
            .onTapGesture {
                showingPhotoDetail = photo
            }
        }
        .id(photo.id)
        .transition(.opacity)
    }
    
    private func handleSwipeLeft() {
        guard viewModel.currentPhoto != nil else { return }
        
        swipeDirection = .left
        
        Task {
            await viewModel.swipeLeft()
            
            if viewModel.showBatchConfirmation {
                showingBatchConfirmation = true
            }
        }
        
        resetSwipe()
    }
    
    private func handleSwipeRight() {
        guard viewModel.currentPhoto != nil else { return }
        
        swipeDirection = .right
        viewModel.swipeRight()
        resetSwipe()
    }
    
    private func resetSwipe() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                dragAmount = .zero
                swipeDirection = .none
            }
        }
    }
}

struct CompletionView: View {
    @EnvironmentObject var viewModel: PhotoSwipeViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("All Done!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                StatRow(icon: "checkmark.circle.fill", title: "Kept", value: "\(viewModel.keptCount)", color: .green)
                StatRow(icon: "trash.circle.fill", title: "Deleted", value: "\(viewModel.deletedCount)", color: .red)
                
                if viewModel.savedSpace > 0 {
                    StatRow(icon: "internaldrive.fill", title: "Space Saved", value: formatBytes(viewModel.savedSpace), color: .blue)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(16)
            
            Button {
                Task {
                    await viewModel.startOver()
                }
            } label: {
                Text("Start Over")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
    }
}