import Foundation
import PhotosUI
import SwiftUI

struct PhotoItem: Identifiable, Equatable {
    let id: UUID
    let asset: PHAsset

    var thumbnailImage: UIImage?

    init(asset: PHAsset) {
        self.id = UUID()
        self.asset = asset
    }

    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum SwipeDirection {
    case left
    case right
}

struct SwipeResult {
    let photo: PhotoItem
    let direction: SwipeDirection
}