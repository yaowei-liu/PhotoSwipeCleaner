import Photos
import SwiftUI

class PhotosService: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var isLoading = false
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    private var allAssets: [PHAsset] = []
    private var seenAssetIdentifiers: Set<String> = []
    private var photoSizes: [String: Int64] = [:]
    
    func requestPhotoLibraryPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        
        if status == .authorized {
            await loadAllAssets()
        }
    }
    
    func loadAllAssets() async {
        isLoading = true
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared]
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        allAssets = []
        seenAssetIdentifiers = []
        photoSizes = [:]
        
        for i in 0..<fetchResult.count {
            let asset = fetchResult.object(at: i)
            allAssets.append(asset)
            photoSizes[asset.localIdentifier] = Int64(asset.pixelWidth * asset.pixelHeight * 4)
        }
        
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
    
    func loadRandomPhotos(count: Int = 20) async {
        isLoading = true
        
        let availableAssets = allAssets.filter { !seenAssetIdentifiers.contains($0.localIdentifier) }
        
        guard !availableAssets.isEmpty else {
            print("No more photos available - all have been shown")
            DispatchQueue.main.async {
                self.photos = []
                self.isLoading = false
            }
            return
        }
        
        var shuffledAssets = availableAssets.shuffled()
        
        if shuffledAssets.count > count {
            shuffledAssets = Array(shuffledAssets.prefix(count))
        }
        
        var loadedPhotos: [Photo] = []
        
        for asset in shuffledAssets {
            seenAssetIdentifiers.insert(asset.localIdentifier)
            
            let photo = Photo(
                id: asset.localIdentifier,
                assetIdentifier: asset.localIdentifier,
                asset: asset
            )
            loadedPhotos.append(photo)
        }
        
        DispatchQueue.main.async {
            self.photos = loadedPhotos
            self.isLoading = false
        }
        
        print("Loaded \(loadedPhotos.count) random photos. Total shown: \(self.seenAssetIdentifiers.count)/\(self.allAssets.count)")
    }
    
    func getPhotoSize(for photo: Photo) -> Int64 {
        return photoSizes[photo.assetIdentifier] ?? 0
    }
    
    func deletePhotos(_ photos: [Photo]) async throws {
        let assetsToDelete = photos.compactMap { photo in
            allAssets.first { $0.localIdentifier == photo.assetIdentifier }
        }
        
        guard !assetsToDelete.isEmpty else {
            throw PhotosError.assetNotFound
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        }
        
        for asset in assetsToDelete {
            allAssets.removeAll { $0.localIdentifier == asset.localIdentifier }
            seenAssetIdentifiers.remove(asset.localIdentifier)
        }
    }
    
    func deletePhoto(_ photo: Photo) async throws {
        try await deletePhotos([photo])
    }
    
    var remainingPhotoCount: Int {
        allAssets.count - seenAssetIdentifiers.count
    }
}

enum PhotosError: Error {
    case assetNotFound
    
    var localizedDescription: String {
        switch self {
        case .assetNotFound:
            return "Photo not found in library"
        }
    }
}