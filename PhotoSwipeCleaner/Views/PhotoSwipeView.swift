import SwiftUI
import UIKit

struct PhotoSwipeView: View {
    @EnvironmentObject var viewModel: PhotoSwipeViewModel
    @State private var dragAmount = CGSize.zero
    @State private var swipeDirection: PhotoSwipeView.SwipeDirection = .none
    @State private var showingPhotoDetail: Photo?
    
    enum SwipeDirection {
        case none, left, right, up
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.photos.isEmpty {
                    ProgressView("Loading photos...")
                        .foregroundColor(.white)
                        .scaleEffect(1.5)
                } else if viewModel.permissionDenied {
                    PermissionDeniedView()
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(MediaCategory.allCases) { category in
                            Button {
                                Task {
                                    await viewModel.selectCategory(category)
                                }
                            } label: {
                                Label(category.rawValue, systemImage: category.icon)
                            }
                        }
                    } label: {
                        Label(viewModel.selectedCategory.rawValue, systemImage: viewModel.selectedCategory.icon)
                            .foregroundColor(.white)
                    }
                }
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
        .fullScreenCover(isPresented: $viewModel.showBatchConfirmation) {
            BatchConfirmationView(
                onConfirm: {
                    Task {
                        await viewModel.confirmBatchDelete()
                    }
                },
                onCancel: {
                    Task {
                        await viewModel.cancelBatchDelete()
                    }
                }
            )
        }
        .sheet(item: $showingPhotoDetail) { photo in
            PhotoDetailView(photo: photo)
        }
        .alert("Photo Cleanup", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragAmount = value.translation
                    if value.translation.height < -50 && abs(value.translation.height) > abs(value.translation.width) {
                        swipeDirection = .up
                    } else if value.translation.width > 50 {
                        swipeDirection = .right
                    } else if value.translation.width < -50 {
                        swipeDirection = .left
                    } else {
                        swipeDirection = .none
                    }
                }
                .onEnded { value in
                    let threshold: CGFloat = 100
                    
                    if value.translation.height < -threshold && abs(value.translation.height) > abs(value.translation.width) {
                        handleSwipeUp()
                    } else if value.translation.width > threshold {
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
        }
        
        resetSwipe()
    }
    
    private func handleSwipeRight() {
        guard viewModel.currentPhoto != nil else { return }

        swipeDirection = .right
        Task {
            await viewModel.swipeRight()
        }
        resetSwipe()
    }

    private func handleSwipeUp() {
        guard viewModel.currentPhoto != nil else { return }

        swipeDirection = .up
        Task {
            await viewModel.swipeUp()
        }
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

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundColor(.orange)

            Text("Photo Access Required")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Enable photo access in Settings to start cleaning your library.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)

            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
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
                StatRow(icon: "star.fill", title: "Favorited", value: "\(viewModel.favoritedCount)", color: .yellow)
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
