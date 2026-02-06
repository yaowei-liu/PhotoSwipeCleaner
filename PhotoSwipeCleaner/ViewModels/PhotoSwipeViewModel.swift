import Combine
import Photos
import SwiftUI

@MainActor
protocol PhotosServicing: AnyObject {
    var photosPublisher: AnyPublisher<[Photo], Never> { get }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }
    var scanProgressPublisher: AnyPublisher<Double, Never> { get }
    var scanScannedCountPublisher: AnyPublisher<Int, Never> { get }
    var scanTotalCountPublisher: AnyPublisher<Int, Never> { get }
    var isScanRunningPublisher: AnyPublisher<Bool, Never> { get }
    var isScanPausedPublisher: AnyPublisher<Bool, Never> { get }
    var duplicateGroupsPublisher: AnyPublisher<[[AssetIndexRecord]], Never> { get }

    var authorizationStatus: PHAuthorizationStatus { get }

    func requestPhotoLibraryPermission() async
    func loadAllAssets() async
    func loadRandomPhotos(category: MediaCategory, count: Int, resetSeen: Bool) async
    func deletePhotos(_ photos: [Photo]) async throws -> Set<String>
    func markPhotoFavorite(_ photo: Photo) async throws
    func remainingPhotoCount(for category: MediaCategory) -> Int
    func startForegroundScan()
    func pauseScan()
    func resumeScan()
    func detectExactDuplicates()
    func deleteDuplicates(in group: [AssetIndexRecord]) async throws -> Int
}

@MainActor
class PhotoSwipeViewModel: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var currentIndex = 0
    @Published var isLoading = false
    @Published var deletedCount = 0
    @Published var keptCount = 0
    @Published var favoritedCount = 0
    @Published var savedSpace: Int64 = 0
    @Published var selectedCategory: MediaCategory = .allPhotos
    @Published var showBatchConfirmation = false
    @Published var pendingDeletions: [Photo] = []
    @Published var showingCompletion = false
    @Published var permissionDenied = false
    @Published var alertMessage: String?
    @Published var processedInBatch = 0

    @Published var scanProgress: Double = 0
    @Published var scanScannedCount: Int = 0
    @Published var scanTotalCount: Int = 0
    @Published var isScanRunning = false
    @Published var isScanPaused = false
    @Published var duplicateGroups: [[AssetIndexRecord]] = []
    
    private let photosService: any PhotosServicing
    private var cancellables = Set<AnyCancellable>()
    private let batchSize = 20
    
    init() {
        self.photosService = PhotosService()
        bindServicePublishers()
    }

    init(photosService: any PhotosServicing) {
        self.photosService = photosService
        bindServicePublishers()
    }

    private func bindServicePublishers() {
        photosService.photosPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.photos, on: self)
            .store(in: &cancellables)
        
        photosService.isLoadingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)

        photosService.scanProgressPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.scanProgress, on: self)
            .store(in: &cancellables)

        photosService.scanScannedCountPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.scanScannedCount, on: self)
            .store(in: &cancellables)

        photosService.scanTotalCountPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.scanTotalCount, on: self)
            .store(in: &cancellables)

        photosService.isScanRunningPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.isScanRunning, on: self)
            .store(in: &cancellables)

        photosService.isScanPausedPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.isScanPaused, on: self)
            .store(in: &cancellables)

        photosService.duplicateGroupsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.duplicateGroups, on: self)
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
        "\(photosService.remainingPhotoCount(for: selectedCategory)) photos remaining"
    }
    
    func requestPermissionAndLoadPhotos() async {
        await photosService.requestPhotoLibraryPermission()
        guard photosService.authorizationStatus == .authorized || photosService.authorizationStatus == .limited else {
            permissionDenied = true
            showingCompletion = false
            return
        }
        permissionDenied = false
        await loadRandomBatch()
    }

    func loadRandomBatch(resetSeen: Bool = false) async {
        currentIndex = 0
        processedInBatch = 0
        pendingDeletions.removeAll()
        showBatchConfirmation = false
        await photosService.loadRandomPhotos(category: selectedCategory, count: batchSize, resetSeen: resetSeen)
        
        if photos.isEmpty {
            showingCompletion = true
        }
    }
    
    func swipeLeft() async {
        guard let photo = currentPhoto else { return }

        pendingDeletions.append(photo)
        savedSpace += photo.fileSize
        processedInBatch += 1
        moveToNextPhoto()
        await finalizeBatchIfNeeded()
    }

    func swipeRight() async {
        guard currentPhoto != nil else { return }
        keptCount += 1
        processedInBatch += 1
        moveToNextPhoto()
        await finalizeBatchIfNeeded()
    }

    func swipeUp() async {
        guard let photo = currentPhoto else { return }
        do {
            try await photosService.markPhotoFavorite(photo)
            favoritedCount += 1
        } catch {
            print("Failed to favorite photo: \(error)")
        }
        processedInBatch += 1
        moveToNextPhoto()
        await finalizeBatchIfNeeded()
    }
    
    private func moveToNextPhoto() {
        if hasMorePhotos {
            currentIndex += 1
        }
    }
    
    func confirmBatchDelete() async {
        guard !pendingDeletions.isEmpty else {
            showBatchConfirmation = false
            await loadRandomBatch()
            return
        }

        do {
            let deletedIdentifiers = try await photosService.deletePhotos(pendingDeletions)
            let deletedInBatch = pendingDeletions.filter { deletedIdentifiers.contains($0.assetIdentifier) }
            let failedInBatch = pendingDeletions.filter { !deletedIdentifiers.contains($0.assetIdentifier) }

            deletedCount += deletedInBatch.count
            pendingDeletions = failedInBatch

            for photo in failedInBatch {
                savedSpace -= photo.fileSize
            }

            if failedInBatch.isEmpty {
                showBatchConfirmation = false
                await loadRandomBatch()
            } else {
                alertMessage = "Deleted \(deletedInBatch.count) photos. \(failedInBatch.count) could not be deleted."
            }
        } catch {
            alertMessage = "Couldn't delete photos. Please try again."
        }
    }

    func cancelBatchDelete() async {
        for photo in pendingDeletions {
            savedSpace -= photo.fileSize
        }
        pendingDeletions.removeAll()
        showBatchConfirmation = false
        await loadRandomBatch()
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
        favoritedCount = 0
        savedSpace = 0
        pendingDeletions.removeAll()
        showingCompletion = false
        await photosService.loadAllAssets()
        await loadRandomBatch(resetSeen: true)
    }

    func selectCategory(_ category: MediaCategory) async {
        guard selectedCategory != category else { return }
        selectedCategory = category
        showingCompletion = false
        await loadRandomBatch()
    }

    func startForegroundScan() {
        photosService.startForegroundScan()
    }

    func pauseOrResumeScan() {
        if isScanPaused {
            photosService.resumeScan()
        } else {
            photosService.pauseScan()
        }
    }

    func detectExactDuplicates() {
        photosService.detectExactDuplicates()
    }

    func deleteDuplicateGroup(_ group: [AssetIndexRecord]) async throws {
        let deleted = try await photosService.deleteDuplicates(in: group)
        deletedCount += deleted
    }

    private func finalizeBatchIfNeeded() async {
        let batchFinished = processedInBatch >= photos.count
        guard batchFinished else { return }

        if pendingDeletions.isEmpty {
            await loadRandomBatch()
        } else {
            showBatchConfirmation = true
        }
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
