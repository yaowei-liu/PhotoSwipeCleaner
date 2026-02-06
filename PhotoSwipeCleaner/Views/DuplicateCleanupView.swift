import Photos
import SwiftUI

struct DuplicateCleanupView: View {
    @EnvironmentObject var viewModel: PhotoSwipeViewModel
    @State private var deletingGroupId: String?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            if viewModel.duplicateGroups.isEmpty {
                Text("No exact duplicates detected yet")
                    .foregroundColor(.secondary)
            }

            ForEach(viewModel.duplicateGroups.enumerated().map { $0 }, id: \.offset) { index, group in
                Section("Group \(index + 1) · \(group.count) items") {
                    Text("Keep first item, delete the rest")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(group) { item in
                                DuplicateThumbView(assetIdentifier: item.assetIdentifier)
                                    .overlay(alignment: .topLeading) {
                                        if item.assetIdentifier == group.first?.assetIdentifier {
                                            Text("KEEP")
                                                .font(.caption2)
                                                .padding(4)
                                                .background(Color.green.opacity(0.8))
                                                .foregroundColor(.white)
                                                .clipShape(Capsule())
                                                .padding(4)
                                        }
                                    }
                            }
                        }
                    }

                    Button(role: .destructive) {
                        deletingGroupId = group.first?.assetIdentifier
                        Task {
                            do {
                                try await viewModel.deleteDuplicateGroup(group)
                            } catch {
                                errorMessage = "Couldn't delete this group. Please try again."
                                showErrorAlert = true
                            }
                            deletingGroupId = nil
                        }
                    } label: {
                        HStack {
                            if deletingGroupId == group.first?.assetIdentifier {
                                ProgressView()
                            }
                            Text("Delete Duplicates in This Group")
                        }
                    }
                }
            }
        }
        .navigationTitle("Duplicate Cleanup")
        .alert("Delete Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

private struct DuplicateThumbView: View {
    let assetIdentifier: String
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 88, height: 88)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 88, height: 88)
                    .overlay(ProgressView())
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = result.firstObject else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 176, height: 176),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                self.image = image
                continuation.resume(returning: ())
            }
        }
    }
}
