import SwiftUI
import Combine

class PhotoSwipeViewModel: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var currentIndex = 0
    @Published var isLoading = false
    @Published var deletedCount = 0
    @Published var keptCount = 0
    @Published var savedSpace: Int64 = 0
    @Published var selectedCategory: MediaCategory = .allPhotos
    @Published var showBatchConfirmation = false
    @Published var pendingDeletions: [Photo] = []
    @Published var showingCompletion = false
    
    private let photosService = PhotosService()
    private var cancellables = Set<AnyCancellable>()
    private let batchSize = 20
    
    init() {
        photosService.$photos
            .receive(on: DispatchQueue.main)
            .assign(to: \.photos, on: self)
            .store(in: &cancellables)
        
        photosService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
    }
    
    var currentPhoto: Photo? {
        guard currentIndex < photos.count else { return nil }
        return photos[currentIndex]
    }
    
    var hasMorePhotos: Bool {
        !photos.isEmpty && currentIndex < photos.count - 1
    }
    
    var progressText: String {
        if photos.isEmpty {
            return "No photos"
        }
        return "\(currentIndex + 1)/\(photos.count)"
    }
    
    var remainingText: String {
        let remaining = photosService.remainingPhotoCount
        return "\(remaining) photos remaining"
    }
    
    func requestPermissionAndLoadPhotos() async {
        await photosService.requestPhotoLibraryPermission()
        await loadRandomBatch()
    }
    
    func loadRandomBatch() async {
        currentIndex = 0
        await photosService.loadRandomPhotos(count: batchSize)
        
        if photos.isEmpty {
            showingCompletion = true
        }
    }
    
    func swipeLeft() async {
        guard let photo = currentPhoto else { return }
        
        pendingDeletions.append(photo)
        savedSpace += Int64(photo.asset.pixelWidth) * Int64(photo.asset.pixelHeight) * 4
        
        if pendingDeletions.count >= batchSize {
            showBatchConfirmation = true
        } else {
            moveToNextPhoto()
        }
    }
    
    func swipeRight() {
        guard let photo = currentPhoto else { return }
        
        keptCount += 1
        moveToNextPhoto()
    }
    
    private func moveToNextPhoto() {
        if hasMorePhotos {
            currentIndex += 1
        }
    }
    
    func confirmBatchDelete() async {
        for photo in pendingDeletions {
            do {
                try await photosService.deletePhoto(photo)
                deletedCount += 1
            } catch {
                print("Failed to delete photo: \(error)")
            }
        }
        
        pendingDeletions.removeAll()
        showBatchConfirmation = false
        
        await loadRandomBatch()
    }
    
    func cancelBatchDelete() {
        pendingDeletions.removeAll()
        showBatchConfirmation = false
    }
    
    func clearAllDeleted() async {
        photos = []
        currentIndex = 0
        pendingDeletions.removeAll()
        showingCompletion = false
        await loadRandomBatch()
    }
    
    func startOver() async {
        deletedCount = 0
        keptCount = 0
        savedSpace = 0
        pendingDeletions.removeAll()
        showingCompletion = false
        await photosService.loadAllAssets()
        await loadRandomBatch()
    }
}

enum MediaCategory: String, CaseIterable, Identifiable {
    case allPhotos = "All Photos"
    case screenshots = "Screenshots"
    case videos = "Videos"
    case recent = "Recent"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .allPhotos: return "photo.on.rectangle"
        case .screenshots: return "camera.viewfinder"
        case .videos: return "video.fill"
        case .recent: return "clock.fill"
        }
    }
}