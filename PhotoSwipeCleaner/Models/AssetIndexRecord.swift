import Foundation

struct AssetIndexRecord: Identifiable, Codable, Equatable {
    let assetIdentifier: String
    let pixelWidth: Int
    let pixelHeight: Int
    let creationDate: Date?
    let fileSize: Int64
    let isLocal: Bool
    let cacheStatus: String
    let fingerprint: String?

    var id: String { assetIdentifier }
}
