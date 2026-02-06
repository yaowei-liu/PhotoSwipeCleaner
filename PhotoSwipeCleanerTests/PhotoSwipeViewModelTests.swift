import XCTest
import Combine
import Photos
@testable import PhotoSwipeCleaner

@MainActor
final class PhotoSwipeViewModelTests: XCTestCase {
    private func settle() async {
        try? await Task.sleep(nanoseconds: 30_000_000)
    }

    private func makePhoto(id: String, fileSize: Int64) -> Photo {
        Photo(id: id, assetIdentifier: id, fileSizeOverride: fileSize)
    }

    func testComputedPropertiesWhenEmpty() {
        let vm = PhotoSwipeViewModel(photosService: MockPhotosService())

        XCTAssertNil(vm.currentPhoto)
        XCTAssertEqual(vm.progressText, "No photos")
        XCTAssertFalse(vm.hasMorePhotos)
    }

    func testLoadRandomBatchShowsCompletionWhenNoPhotos() async {
        let service = MockPhotosService()
        service.queuedBatches = [[]]
        let vm = PhotoSwipeViewModel(photosService: service)

        await vm.loadRandomBatch()
        await settle()

        XCTAssertTrue(vm.showingCompletion)
        XCTAssertEqual(service.loadRandomPhotosCallCount, 1)
    }

    func testSwipeLeftTracksPendingDeletionAndSavedSpace() async {
        let service = MockPhotosService()
        service.queuedBatches = [[makePhoto(id: "p1", fileSize: 128)]]
        let vm = PhotoSwipeViewModel(photosService: service)

        await vm.loadRandomBatch()
        await settle()
        await vm.swipeLeft()
        await settle()

        XCTAssertEqual(vm.pendingDeletions.count, 1)
        XCTAssertEqual(vm.pendingDeletions.first?.assetIdentifier, "p1")
        XCTAssertEqual(vm.savedSpace, 128)
        XCTAssertTrue(vm.showBatchConfirmation)
    }

    func testSwipeRightIncrementsKeptAndLoadsNextBatch() async {
        let service = MockPhotosService()
        service.queuedBatches = [[makePhoto(id: "p1", fileSize: 10)], []]
        let vm = PhotoSwipeViewModel(photosService: service)

        await vm.loadRandomBatch()
        await settle()
        await vm.swipeRight()
        await settle()

        XCTAssertEqual(vm.keptCount, 1)
        XCTAssertEqual(service.loadRandomPhotosCallCount, 2)
    }

    func testConfirmBatchDeleteHandlesPartialFailure() async {
        let service = MockPhotosService()
        let first = makePhoto(id: "a", fileSize: 100)
        let second = makePhoto(id: "b", fileSize: 200)
        service.deletePhotosResult = ["a"]
        let vm = PhotoSwipeViewModel(photosService: service)

        vm.pendingDeletions = [first, second]
        vm.savedSpace = 300
        vm.showBatchConfirmation = true

        await vm.confirmBatchDelete()
        await settle()

        XCTAssertEqual(vm.deletedCount, 1)
        XCTAssertEqual(vm.pendingDeletions.map(\.assetIdentifier), ["b"])
        XCTAssertEqual(vm.savedSpace, 100)
        XCTAssertNotNil(vm.alertMessage)
        XCTAssertTrue(vm.showBatchConfirmation)
    }

    func testCancelBatchDeleteRestoresStateAndLoadsNextBatch() async {
        let service = MockPhotosService()
        service.queuedBatches = [[]]
        let vm = PhotoSwipeViewModel(photosService: service)

        vm.pendingDeletions = [
            makePhoto(id: "a", fileSize: 100),
            makePhoto(id: "b", fileSize: 200)
        ]
        vm.savedSpace = 300
        vm.showBatchConfirmation = true

        await vm.cancelBatchDelete()
        await settle()

        XCTAssertEqual(vm.pendingDeletions.count, 0)
        XCTAssertEqual(vm.savedSpace, 0)
        XCTAssertFalse(vm.showBatchConfirmation)
        XCTAssertEqual(service.loadRandomPhotosCallCount, 1)
    }

    func testStartOverResetsCountersAndRequestsFreshBatch() async {
        let service = MockPhotosService()
        service.queuedBatches = [[]]
        let vm = PhotoSwipeViewModel(photosService: service)

        vm.deletedCount = 4
        vm.keptCount = 7
        vm.favoritedCount = 3
        vm.savedSpace = 999
        vm.pendingDeletions = [makePhoto(id: "x", fileSize: 9)]
        vm.showingCompletion = true

        await vm.startOver()
        await settle()

        XCTAssertEqual(vm.deletedCount, 0)
        XCTAssertEqual(vm.keptCount, 0)
        XCTAssertEqual(vm.favoritedCount, 0)
        XCTAssertEqual(vm.savedSpace, 0)
        XCTAssertEqual(vm.pendingDeletions.count, 0)
        XCTAssertFalse(vm.showingCompletion)
        XCTAssertEqual(service.loadAllAssetsCallCount, 1)
        XCTAssertEqual(service.lastResetSeen, true)
    }

    func testSelectCategorySkipsWhenSameAndLoadsWhenChanged() async {
        let service = MockPhotosService()
        let vm = PhotoSwipeViewModel(photosService: service)

        await vm.selectCategory(.allPhotos)
        XCTAssertEqual(service.loadRandomPhotosCallCount, 0)

        await vm.selectCategory(.videos)
        await settle()

        XCTAssertEqual(vm.selectedCategory, .videos)
        XCTAssertEqual(service.loadRandomPhotosCallCount, 1)
    }

    func testPauseOrResumeScanCallsServiceMethods() {
        let service = MockPhotosService()
        let vm = PhotoSwipeViewModel(photosService: service)

        service.isScanPausedSubject.send(false)
        vm.pauseOrResumeScan()
        XCTAssertEqual(service.pauseScanCallCount, 1)

        service.isScanPausedSubject.send(true)
        vm.pauseOrResumeScan()
        XCTAssertEqual(service.resumeScanCallCount, 1)
    }
}

@MainActor
final class MockPhotosService: PhotosServicing {
    let photosSubject = CurrentValueSubject<[Photo], Never>([])
    let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
    let scanProgressSubject = CurrentValueSubject<Double, Never>(0)
    let scanScannedCountSubject = CurrentValueSubject<Int, Never>(0)
    let scanTotalCountSubject = CurrentValueSubject<Int, Never>(0)
    let isScanRunningSubject = CurrentValueSubject<Bool, Never>(false)
    let isScanPausedSubject = CurrentValueSubject<Bool, Never>(false)
    let duplicateGroupsSubject = CurrentValueSubject<[[AssetIndexRecord]], Never>([])

    var photosPublisher: AnyPublisher<[Photo], Never> { photosSubject.eraseToAnyPublisher() }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { isLoadingSubject.eraseToAnyPublisher() }
    var scanProgressPublisher: AnyPublisher<Double, Never> { scanProgressSubject.eraseToAnyPublisher() }
    var scanScannedCountPublisher: AnyPublisher<Int, Never> { scanScannedCountSubject.eraseToAnyPublisher() }
    var scanTotalCountPublisher: AnyPublisher<Int, Never> { scanTotalCountSubject.eraseToAnyPublisher() }
    var isScanRunningPublisher: AnyPublisher<Bool, Never> { isScanRunningSubject.eraseToAnyPublisher() }
    var isScanPausedPublisher: AnyPublisher<Bool, Never> { isScanPausedSubject.eraseToAnyPublisher() }
    var duplicateGroupsPublisher: AnyPublisher<[[AssetIndexRecord]], Never> { duplicateGroupsSubject.eraseToAnyPublisher() }

    var authorizationStatus: PHAuthorizationStatus = .authorized
    var remainingCount = 0
    var queuedBatches: [[Photo]] = []
    var deletePhotosResult: Set<String> = []
    var deletePhotosError: Error?
    var deleteDuplicatesResult = 0

    var loadRandomPhotosCallCount = 0
    var loadAllAssetsCallCount = 0
    var pauseScanCallCount = 0
    var resumeScanCallCount = 0
    var lastResetSeen = false

    func requestPhotoLibraryPermission() async {}

    func loadAllAssets() async {
        loadAllAssetsCallCount += 1
    }

    func loadRandomPhotos(category: MediaCategory, count: Int, resetSeen: Bool) async {
        loadRandomPhotosCallCount += 1
        lastResetSeen = resetSeen
        if !queuedBatches.isEmpty {
            photosSubject.send(queuedBatches.removeFirst())
        }
    }

    func deletePhotos(_ photos: [Photo]) async throws -> Set<String> {
        if let deletePhotosError {
            throw deletePhotosError
        }
        return deletePhotosResult
    }

    func markPhotoFavorite(_ photo: Photo) async throws {}

    func remainingPhotoCount(for category: MediaCategory) -> Int {
        remainingCount
    }

    func startForegroundScan() {}

    func pauseScan() {
        pauseScanCallCount += 1
    }

    func resumeScan() {
        resumeScanCallCount += 1
    }

    func detectExactDuplicates() {}

    func deleteDuplicates(in group: [AssetIndexRecord]) async throws -> Int {
        deleteDuplicatesResult
    }
}
