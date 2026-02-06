import Foundation
import Photos

struct Photo: Identifiable, Equatable {
    let id: String
    let assetIdentifier: String
    let asset: PHAsset?
    private let fileSizeOverride: Int64?

    init(id: String, assetIdentifier: String, asset: PHAsset? = nil, fileSizeOverride: Int64? = nil) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.asset = asset
        self.fileSizeOverride = fileSizeOverride
    }

    var fileSize: Int64 {
        if let fileSizeOverride {
            return fileSizeOverride
        }
        guard let asset else {
            return 0
        }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first,
              let size = resource.value(forKey: "fileSize") as? CLong else {
            return Int64(asset.pixelWidth * asset.pixelHeight * 4)
        }
        return Int64(size)
    }
    
    static func == (lhs: Photo, rhs: Photo) -> Bool {
        lhs.id == rhs.id
    }
}
