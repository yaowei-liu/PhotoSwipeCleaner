import SwiftUI
import Photos

struct PhotoDetailView: View {
    let photo: Photo
    @Environment(\.dismiss) var dismiss
    @State private var showingFullImage = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        if showingFullImage {
                            GeometryReader { geometry in
                                Image(uiImage: loadFullImage())
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geometry.size.width, height: geometry.size.width * 1.5)
                            }
                            .frame(maxHeight: .infinity)
                        } else {
                            Image(uiImage: loadFullImage())
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 400)
                        }
                    }
                    .background(Color.black)
                    .cornerRadius(12)
                    
                    metadataSection
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFullImage.toggle()
                    } label: {
                        Image(systemName: showingFullImage ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Metadata")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                MetadataRow(icon: "calendar", title: "Date Taken", value: formatDate(photo.asset.creationDate))
                MetadataRow(icon: "folder", title: "Collection", value: photo.asset.collectionNames.first ?? "Library")
                MetadataRow(icon: "arrow.left.and.right", title: "Dimensions", value: "\(photo.asset.pixelWidth) × \(photo.asset.pixelHeight)")
                MetadataRow(icon: "doc", title: "File Size", value: formatFileSize(fileSize))
                MetadataRow(icon: "location", title: "Location", value: photo.asset.location != nil ? "Has Location" : "No Location")
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
    }
    
    private var fileSize: Int64 {
        Int64(photo.asset.pixelWidth * photo.asset.pixelHeight * 4)
    }
    
    private func loadFullImage() -> UIImage {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = true
        
        var result: UIImage?
        let semaphore = DispatchSemaphore(value: 0)
        
        manager.requestImage(for: photo.asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, info in
            result = image
            semaphore.signal()
        }
        
        semaphore.wait()
        return result ?? UIImage()
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct MetadataRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

extension PHAsset {
    var collectionNames: [String] {
        var names: [String] = []
        let options = PHFetchOptions()
        let result = PHAssetCollection.fetchAssetCollectionsContaining(self, with: .album, options: nil)
        result.enumerateObjects { collection, _, _ in
            names.append(collection.localizedTitle ?? "Album")
        }
        return names
    }
}