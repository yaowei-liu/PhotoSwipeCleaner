import Foundation
import Photos
import UIKit

final class PhotoService {

    static let shared = PhotoService()

    private init() {}

    /// Fetches the most recent photos from the library
    /// - Parameter limit: Number of photos to fetch
    /// - Returns: Array of PhotoItem objects
    func fetchRecentPhotos(limit: Int = 100) async throws -> [PhotoItem] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit

        let results = PHAsset.fetchAssets(with: .image, options: options)

        var photos: [PhotoItem] = []

        try await PHImageManager.default().requestImage(
            for: results.objects(at: 0),
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: nil
        ) { image, _ in
            // This is async, so we'll fetch thumbnails separately
        }

        // For simplicity in MVP, fetch synchronously with thumbnail
        results.enumerateObjects { asset, _, _ in
            let photo = PhotoItem(asset: asset)
            photos.append(photo)
        }

        return photos
    }

    /// Gets a thumbnail for a photo item
    func getThumbnail(for item: PhotoItem, size: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast

            manager.requestImage(
                for: item.asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// Gets a full-size image for a photo item
    func getFullImage(for item: PhotoItem) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            manager.requestImage(
                for: item.asset,
                targetSize: CGSize(width: item.asset.pixelWidth, height: item.asset.pixelHeight),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// Deletes photos from the library (moves to Recently Deleted)
    func deletePhotos(_ items: [PhotoItem]) async throws {
        let assets = items.map { $0.asset }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }
    }

    /// Requests photo library authorization
    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }
}