import Foundation
import Photos
import SwiftUI

@MainActor
final class PhotoCleanupViewModel: ObservableObject {

    @Published var photos: [PhotoItem] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasMorePhotos: Bool = true
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    // For batch operations
    @Published var photosToDelete: [PhotoItem] = []
    @Published var photosToKeep: [PhotoItem] = []

    private let photoService = PhotoService.shared
    private let batchSize = 50

    var currentPhoto: PhotoItem? {
        guard currentIndex < photos.count else { return nil }
        return photos[currentIndex]
    }

    var progress: String {
        "\(currentIndex + 1) / \(photos.count)"
    }

    var canSwipe: Bool {
        currentIndex < photos.count
    }

    init() {
        Task {
            await checkAuthorization()
        }
    }

    func checkAuthorization() async {
        let status = await photoService.requestAuthorization()
        await MainActor.run {
            self.authorizationStatus = status
        }
    }

    func loadPhotos() async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            errorMessage = "Photo library access not granted"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let fetchedPhotos = try await photoService.fetchRecentPhotos(limit: batchSize)
            await MainActor.run {
                self.photos = fetchedPhotos
                self.currentIndex = 0
                self.hasMorePhotos = fetchedPhotos.count == batchSize
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load photos: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func swipeLeft() async {
        guard canSwipe, let photo = currentPhoto else { return }

        // Mark for deletion
        photosToDelete.append(photo)
        await advanceToNextPhoto()
    }

    func swipeRight() async {
        guard canSwipe, let photo = currentPhoto else { return }

        // Mark to keep (do nothing, just advance)
        await advanceToNextPhoto()
    }

    private func advanceToNextPhoto() async {
        await MainActor.run {
            if currentIndex < photos.count - 1 {
                currentIndex += 1
            } else {
                // End of current batch
                hasMorePhotos = false
            }
        }
    }

    func confirmDeletions() async {
        guard !photosToDelete.isEmpty else { return }

        do {
            try await photoService.deletePhotos(photosToDelete)

            // Remove deleted photos from the list
            await MainActor.run {
                // Remove all deleted photos from the main list
                let deleteIds = Set(photosToDelete.map { $0.id })
                photos = photos.filter { !deleteIds.contains($0.id) }

                // Adjust current index if needed
                if currentIndex >= photos.count {
                    currentIndex = max(0, photos.count - 1)
                }

                // Clear the deletion queue
                photosToDelete.removeAll()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete photos: \(error.localizedDescription)"
            }
        }
    }

    func reset() {
        photosToDelete.removeAll()
        photosToKeep.removeAll()
        currentIndex = 0
    }
}