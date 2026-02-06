import XCTest
@testable import PhotoSwipeCleaner

@MainActor
final class PhotosServiceDuplicateTests: XCTestCase {
    private func makeRecord(id: String, date: Date?, fingerprint: String?) -> AssetIndexRecord {
        AssetIndexRecord(
            assetIdentifier: id,
            pixelWidth: 100,
            pixelHeight: 100,
            creationDate: date,
            fileSize: 10,
            isLocal: true,
            cacheStatus: "local",
            fingerprint: fingerprint
        )
    }

    func testDetectExactDuplicatesGroupsByFingerprintAndSorts() {
        let service = PhotosService()
        let d1 = Date(timeIntervalSince1970: 100)
        let d2 = Date(timeIntervalSince1970: 200)
        let d3 = Date(timeIntervalSince1970: 300)

        service.indexRecords = [
            "a": makeRecord(id: "a", date: d2, fingerprint: "fp1"),
            "b": makeRecord(id: "b", date: d1, fingerprint: "fp1"),
            "c": makeRecord(id: "c", date: nil, fingerprint: "fp2"),
            "d": makeRecord(id: "d", date: d3, fingerprint: "fp2"),
            "e": makeRecord(id: "e", date: d1, fingerprint: "fp2"),
            "f": makeRecord(id: "f", date: d1, fingerprint: nil)
        ]

        service.detectExactDuplicates()

        XCTAssertEqual(service.duplicateGroups.count, 2)
        XCTAssertEqual(service.duplicateGroups[0].count, 3)
        XCTAssertEqual(service.duplicateGroups[1].count, 2)
        XCTAssertEqual(service.duplicateGroups[0].map(\.assetIdentifier), ["c", "e", "d"])
        XCTAssertEqual(service.duplicateGroups[1].map(\.assetIdentifier), ["b", "a"])
    }
}
