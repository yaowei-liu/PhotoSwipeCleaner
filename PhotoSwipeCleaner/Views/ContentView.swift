import SwiftUI
import Photos

struct ContentView: View {
    @EnvironmentObject var viewModel: PhotoCleanupViewModel
    @State private var showPermissionAlert = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Swipe View
            NavigationStack {
                ZStack {
                    if viewModel.isLoading {
                        ProgressView("Loading photos...")
                    } else if viewModel.canSwipe, let photo = viewModel.currentPhoto {
                        PhotoCardView(photo: photo)
                            .padding()
                            .onChange(of: viewModel.currentIndex) { _, _ in
                                // Force refresh of card view
                            }
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)

                            Text("All done!")
                                .font(.title)

                            Text("You've reviewed \(viewModel.photos.count) photos")
                                .foregroundColor(.secondary)

                            if !viewModel.photosToDelete.isEmpty {
                                Button {
                                    Task {
                                        await viewModel.confirmDeletions()
                                    }
                                } label: {
                                    Text("Delete \(viewModel.photosToDelete.count) Photos")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(10)
                                }
                                .padding(.top)
                            }
                        }
                    }
                }
                .navigationTitle("Swipe to Clean")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text(viewModel.progress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tabItem {
                Label("Clean", systemImage: "arrow.left.arrow.right")
            }
            .tag(0)

            // Gallery View
            NavigationStack {
                PhotoGridView()
                    .navigationTitle("All Photos")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                Task {
                                    await viewModel.loadPhotos()
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Gallery", systemImage: "photo.on.rectangle")
            }
            .tag(1)
        }
        .task {
            await checkAndRequestPermission()
        }
        .alert("Photo Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please grant photo library access in Settings to use this app.")
        }
    }

    private func checkAndRequestPermission() async {
        let status = await PhotoService.shared.requestAuthorization()

        await MainActor.run {
            viewModel.authorizationStatus = status

            switch status {
            case .notDetermined:
                Task {
                    await viewModel.loadPhotos()
                }
            case .denied, .restricted:
                showPermissionAlert = true
            case .authorized, .limited:
                Task {
                    await viewModel.loadPhotos()
                }
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PhotoCleanupViewModel())
}