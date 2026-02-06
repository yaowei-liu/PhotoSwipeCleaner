import XCTest
@testable import PhotoSwipeCleaner

final class ModelsAndCategoryTests: XCTestCase {
    func testAssetIndexRecordIdMatchesIdentifier() {
        let record = AssetIndexRecord(
            assetIdentifier: "asset-1",
            pixelWidth: 10,
            pixelHeight: 20,
            creationDate: nil,
            fileSize: 30,
            isLocal: true,
            cacheStatus: "local",
            fingerprint: nil
        )

        XCTAssertEqual(record.id, "asset-1")
    }

    func testMediaCategoryIcons() {
        XCTAssertEqual(MediaCategory.allPhotos.icon, "photo.on.rectangle")
        XCTAssertEqual(MediaCategory.screenshots.icon, "camera.viewfinder")
        XCTAssertEqual(MediaCategory.videos.icon, "video.fill")
        XCTAssertEqual(MediaCategory.recent.icon, "clock.fill")
    }

    func testMediaCategoryCountAndIds() {
        XCTAssertEqual(MediaCategory.allCases.count, 4)
        XCTAssertEqual(MediaCategory.recent.id, MediaCategory.recent.rawValue)
    }
}
