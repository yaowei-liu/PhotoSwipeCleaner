import XCTest
@testable import PhotoSwipeCleaner

final class PhotoIndexStoreTests: XCTestCase {
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testLoadReturnsEmptyWhenFileDoesNotExist() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = PhotoIndexStore(baseDirectory: root)
        XCTAssertTrue(store.load().isEmpty)
    }

    func testSaveAndLoadRoundTrip() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = PhotoIndexStore(baseDirectory: root)
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let records: [String: AssetIndexRecord] = [
            "one": AssetIndexRecord(
                assetIdentifier: "one",
                pixelWidth: 1200,
                pixelHeight: 800,
                creationDate: created,
                fileSize: 1024,
                isLocal: true,
                cacheStatus: "local",
                fingerprint: "abc"
            )
        ]

        store.save(records)
        let loaded = store.load()

        XCTAssertEqual(loaded, records)
    }
}
