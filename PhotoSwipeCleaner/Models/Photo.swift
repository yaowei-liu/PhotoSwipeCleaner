import Foundation
import Photos

struct Photo: Identifiable, Equatable {
    let id: String
    let assetIdentifier: String
    let asset: PHAsset
    
    var fileSize: Int64 {
        return Int64(asset.pixelWidth * asset.pixelHeight * 4)
    }
    
    static func == (lhs: Photo, rhs: Photo) -> Bool {
        lhs.id == rhs.id
    }
}