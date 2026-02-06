import Photos
import SwiftUI
import CryptoKit
import Combine

@MainActor
class PhotosService: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var isLoading = false
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    @Published var scanProgress: Double = 0
    @Published var scanScannedCount: Int = 0
    @Published var scanTotalCount: Int = 0
    @Published var isScanRunning = false
    @Published var isScanPaused = false
    @Published var indexRecords: [String: AssetIndexRecord] = [:]
    @Published var duplicateGroups: [[AssetIndexRecord]] = []

    private var assetsByCategory: [MediaCategory: [PHAsset]] = [:]
    private var seenByCategory: [MediaCategory: Set<String>] = [:]
    private let cachingManager = PHCachingImageManager()
    private let indexStore = PhotoIndexStore()
    private var scanTask: Task<Void, Never>?

    private struct DuplicatePrehashBucket: Hashable {
        let pixelWidth: Int
        let pixelHeight: Int
        let fileSizeBucket: Int64
    }

    init() {
        indexRecords = indexStore.load()
    }

    func requestPhotoLibraryPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            authorizationStatus = status
        }
    }

    func loadAllAssets() async {
        await MainActor.run {
            assetsByCategory.removeAll()
            seenByCategory.removeAll()
            photos = []
        }
    }

    func loadRandomPhotos(category: MediaCategory, count: Int = 20, resetSeen: Bool = false) async {
        await MainActor.run {
            isLoading = true
        }

        let assets = fetchAssets(for: category)
        assetsByCategory[category] = assets

        if resetSeen {
            seenByCategory[category] = []
        }

        var seen = seenByCategory[category] ?? []
        let availableAssets = assets.filter { !seen.contains($0.localIdentifier) }

        guard !availableAssets.isEmpty else {
            await MainActor.run {
                photos = []
                isLoading = false
            }
            return
        }

        let selectedAssets = Array(availableAssets.shuffled().prefix(count))
        let loadedPhotos = selectedAssets.map {
            Photo(id: $0.localIdentifier, assetIdentifier: $0.localIdentifier, asset: $0)
        }

        let targetSize = CGSize(width: 400, height: 600)
        cachingManager.startCachingImages(
            for: selectedAssets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )

        selectedAssets.forEach { seen.insert($0.localIdentifier) }
        seenByCategory[category] = seen

        await MainActor.run {
            photos = loadedPhotos
            isLoading = false
        }
    }

    func startForegroundScan() {
        guard scanTask == nil else { return }

        isScanRunning = true
        isScanPaused = false
        scanTask = Task { [weak self] in
            await self?.runScan()
        }
    }

    func pauseScan() {
        guard isScanRunning else { return }
        isScanPaused = true
    }

    func resumeScan() {
        guard isScanRunning else { return }
        isScanPaused = false
    }

    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanRunning = false
        isScanPaused = false
    }

    func detectExactDuplicates() {
        let groups = Dictionary(grouping: indexRecords.values.filter { $0.fingerprint != nil }, by: { $0.fingerprint! })
            .values
            .filter { $0.count > 1 }
            .map { group in
                group.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
            }
            .sorted { $0.count > $1.count }
        duplicateGroups = groups
    }

    func deleteDuplicates(in group: [AssetIndexRecord]) async throws -> Int {
        guard group.count > 1 else { return 0 }
        let deleteTargets = group.dropFirst()
        let photosToDelete: [Photo] = deleteTargets.compactMap {
            fetchAsset(by: $0.assetIdentifier).map {
                Photo(id: $0.localIdentifier, assetIdentifier: $0.localIdentifier, asset: $0)
            }
        }
        let deletedIdentifiers = try await deletePhotos(photosToDelete)

        for id in deletedIdentifiers {
            indexRecords.removeValue(forKey: id)
        }
        indexStore.save(indexRecords)
        detectExactDuplicates()
        return deletedIdentifiers.count
    }

    func deletePhoto(_ photo: Photo) async throws {
        _ = try await deletePhotos([photo])
    }

    func markPhotoFavorite(_ photo: Photo) async throws {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photo.assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw PhotosError.assetNotFound
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = true
        }
    }

    func deletePhotos(_ photos: [Photo]) async throws -> Set<String> {
        let identifiers = photos.map { $0.assetIdentifier }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)

        var assetsToDelete: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assetsToDelete.append(asset)
        }

        guard !assetsToDelete.isEmpty else {
            throw PhotosError.assetNotFound
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        }

        let deletedSet = Set(assetsToDelete.map { $0.localIdentifier })
        for category in MediaCategory.allCases {
            if var seen = seenByCategory[category] {
                seen.subtract(deletedSet)
                seenByCategory[category] = seen
            }
            if let cached = assetsByCategory[category] {
                assetsByCategory[category] = cached.filter { !deletedSet.contains($0.localIdentifier) }
            }
        }
        return deletedSet
    }

    func remainingPhotoCount(for category: MediaCategory) -> Int {
        let assets = assetsByCategory[category] ?? fetchAssets(for: category)
        let seen = seenByCategory[category] ?? []
        return max(0, assets.count - seen.count)
    }

    private func fetchAssets(for category: MediaCategory) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared]

        let fetchResult: PHFetchResult<PHAsset>
        switch category {
        case .allPhotos:
            fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        case .screenshots:
            options.predicate = NSPredicate(
                format: "((mediaSubtype & %d) != 0)",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
            fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        case .videos:
            fetchResult = PHAsset.fetchAssets(with: .video, options: options)
        case .recent:
            let recentDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            options.predicate = NSPredicate(format: "creationDate >= %@", recentDate as NSDate)
            fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        }

        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private func runScan() async {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        let metadataCount = fetchResult.count

        await MainActor.run {
            scanTotalCount = metadataCount
            scanScannedCount = 0
            scanProgress = 0
        }

        var records = indexRecords
        var scanCancelled = false

        // Phase 1: collect lightweight metadata for all assets.
        for index in 0..<metadataCount {
            if await waitIfPausedOrCancelled() {
                scanCancelled = true
                break
            }

            let asset = fetchResult.object(at: index)
            let record = await buildIndexRecord(for: asset, includeFingerprint: false)
            records[asset.localIdentifier] = record

            if index % 25 == 0 {
                indexStore.save(records)
            }

            await MainActor.run {
                scanScannedCount = index + 1
                if scanTotalCount > 0 {
                    scanProgress = Double(scanScannedCount) / Double(scanTotalCount)
                }
            }
        }

        // Phase 2: compute fingerprints only for duplicate candidates.
        if !scanCancelled {
            let candidateIdentifiers = candidateIdentifiersForFingerprinting(from: records)
            let totalWork = metadataCount + candidateIdentifiers.count

            await MainActor.run {
                scanTotalCount = totalWork
                if totalWork > 0 {
                    scanProgress = Double(scanScannedCount) / Double(totalWork)
                }
            }

            for (candidateIndex, identifier) in candidateIdentifiers.enumerated() {
                if await waitIfPausedOrCancelled() {
                    scanCancelled = true
                    break
                }

                guard let asset = fetchAsset(by: identifier),
                      var record = records[identifier] else {
                    continue
                }

                record = AssetIndexRecord(
                    assetIdentifier: record.assetIdentifier,
                    pixelWidth: record.pixelWidth,
                    pixelHeight: record.pixelHeight,
                    creationDate: record.creationDate,
                    fileSize: record.fileSize,
                    isLocal: record.isLocal,
                    cacheStatus: record.cacheStatus,
                    fingerprint: await fingerprintForExactDuplicate(asset: asset, localOnly: true)
                )
                records[identifier] = record

                if candidateIndex % 25 == 0 {
                    indexStore.save(records)
                }

                await MainActor.run {
                    scanScannedCount = metadataCount + candidateIndex + 1
                    if scanTotalCount > 0 {
                        scanProgress = Double(scanScannedCount) / Double(scanTotalCount)
                    }
                }
            }
        }

        indexStore.save(records)
        let finalRecords = records
        await MainActor.run {
            indexRecords = finalRecords
            isScanRunning = false
            isScanPaused = false
            scanTask = nil
        }
    }

    private func buildIndexRecord(for asset: PHAsset, includeFingerprint: Bool) async -> AssetIndexRecord {
        let fileSize = assetResourceFileSize(for: asset)
        let localAvailable = await checkLocalAvailability(for: asset)
        let fingerprint = includeFingerprint
            ? await fingerprintForExactDuplicate(asset: asset, localOnly: true)
            : nil

        return AssetIndexRecord(
            assetIdentifier: asset.localIdentifier,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            creationDate: asset.creationDate,
            fileSize: fileSize,
            isLocal: localAvailable,
            cacheStatus: localAvailable ? "local" : "icloud",
            fingerprint: fingerprint
        )
    }

    private func waitIfPausedOrCancelled() async -> Bool {
        if Task.isCancelled { return true }
        while isScanPaused {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return true }
        }
        return false
    }

    private func candidateIdentifiersForFingerprinting(from records: [String: AssetIndexRecord]) -> [String] {
        let localRecords = records.values.filter { $0.isLocal }
        let grouped = Dictionary(grouping: localRecords) { record in
            DuplicatePrehashBucket(
                pixelWidth: record.pixelWidth,
                pixelHeight: record.pixelHeight,
                fileSizeBucket: max(record.fileSize / 65_536, 0)
            )
        }

        return grouped.values
            .filter { $0.count > 1 }
            .flatMap { $0.map(\.assetIdentifier) }
            .sorted()
    }

    private func checkLocalAvailability(for asset: PHAsset) async -> Bool {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 40, height: 40),
                contentMode: .aspectFill,
                options: options
            ) { _, info in
                let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                continuation.resume(returning: !inCloud)
            }
        }
    }

    private func fingerprintForExactDuplicate(asset: PHAsset, localOnly: Bool) async -> String? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = !localOnly
            options.deliveryMode = .highQualityFormat
            options.version = .current

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                if localOnly && inCloud {
                    continuation.resume(returning: nil)
                    return
                }
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }
                let digest = SHA256.hash(data: data)
                let hash = digest.compactMap { String(format: "%02x", $0) }.joined()
                continuation.resume(returning: hash)
            }
        }
    }

    private func assetResourceFileSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first,
              let size = resource.value(forKey: "fileSize") as? CLong else {
            return Int64(asset.pixelWidth * asset.pixelHeight * 4)
        }
        return Int64(size)
    }

    private func fetchAsset(by identifier: String) -> PHAsset? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return result.firstObject
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

@MainActor
extension PhotosService: PhotosServicing {
    var photosPublisher: AnyPublisher<[Photo], Never> {
        $photos.eraseToAnyPublisher()
    }

    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }

    var scanProgressPublisher: AnyPublisher<Double, Never> {
        $scanProgress.eraseToAnyPublisher()
    }

    var scanScannedCountPublisher: AnyPublisher<Int, Never> {
        $scanScannedCount.eraseToAnyPublisher()
    }

    var scanTotalCountPublisher: AnyPublisher<Int, Never> {
        $scanTotalCount.eraseToAnyPublisher()
    }

    var isScanRunningPublisher: AnyPublisher<Bool, Never> {
        $isScanRunning.eraseToAnyPublisher()
    }

    var isScanPausedPublisher: AnyPublisher<Bool, Never> {
        $isScanPaused.eraseToAnyPublisher()
    }

    var duplicateGroupsPublisher: AnyPublisher<[[AssetIndexRecord]], Never> {
        $duplicateGroups.eraseToAnyPublisher()
    }
}
