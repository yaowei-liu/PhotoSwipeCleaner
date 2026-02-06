import SwiftUI
import Photos
import CoreLocation

struct PhotoDetailView: View {
    let photo: Photo
    @Environment(\.dismiss) var dismiss
    @State private var showingFullImage = false
    @State private var locationString: String = "Loading..."
    @State private var uiImage: UIImage?
    @State private var zoomScale: CGFloat = 1
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        if let image = uiImage {
                            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .frame(maxHeight: showingFullImage ? .infinity : 400)
                                    .scaleEffect(zoomScale)
                                    .gesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                zoomScale = min(max(value, 1), 5)
                                            }
                                            .onEnded { _ in
                                                if zoomScale < 1.02 { zoomScale = 1 }
                                            }
                                    )
                                    .onTapGesture(count: 2) {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            zoomScale = zoomScale > 1 ? 1 : 2
                                        }
                                    }
                            }
                        } else {
                            ProgressView()
                                .scaleEffect(1.5)
                                .frame(height: 400)
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
                        if !showingFullImage { zoomScale = 1 }
                    } label: {
                        Image(systemName: showingFullImage ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                loadImage()
                loadLocation()
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Metadata")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                MetadataRow(icon: "calendar", title: "Date Taken", value: formatDate(photo.asset?.creationDate))
                MetadataRow(icon: "folder", title: "Collection", value: photo.asset?.collectionNames.first ?? "Library")
                MetadataRow(
                    icon: "arrow.left.and.right",
                    title: "Dimensions",
                    value: photo.asset.map { "\($0.pixelWidth) × \($0.pixelHeight)" } ?? "Unknown"
                )
                MetadataRow(icon: "doc", title: "File Size", value: formatFileSize(fileSize))
                
                if photo.asset?.location != nil {
                    MetadataRow(icon: "location.fill", title: "Location", value: locationString)
                    
                    if let location = photo.asset?.location {
                        MetadataRow(icon: "mappin", title: "Coordinates", value: formatCoordinates(location))
                    }
                } else {
                    MetadataRow(icon: "location.slash", title: "Location", value: "No Location Data")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
    }
    
    private var fileSize: Int64 {
        photo.fileSize
    }
    
    private func loadImage() {
        guard let asset = photo.asset else { return }
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, info in
            DispatchQueue.main.async {
                self.uiImage = image
            }
        }
    }
    
    private func loadLocation() {
        guard let location = photo.asset?.location else {
            locationString = "No Location Data"
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    var parts: [String] = []
                    
                    if let name = placemark.name {
                        parts.append(name)
                    }
                    if let locality = placemark.locality {
                        parts.append(locality)
                    }
                    if let administrativeArea = placemark.administrativeArea {
                        parts.append(administrativeArea)
                    }
                    if let country = placemark.country {
                        parts.append(country)
                    }
                    
                    if parts.isEmpty {
                        self.locationString = formatCoordinates(location)
                    } else {
                        self.locationString = parts.prefix(3).joined(separator: ", ")
                    }
                } else {
                    self.locationString = formatCoordinates(location)
                }
            }
        }
    }
    
    private func formatCoordinates(_ location: CLLocation) -> String {
        let lat = String(format: "%.4f", location.coordinate.latitude)
        let lon = String(format: "%.4f", location.coordinate.longitude)
        return "\(lat), \(lon)"
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
                .multilineTextAlignment(.trailing)
        }
    }
}

extension PHAsset {
    var collectionNames: [String] {
        var names: [String] = []
        let result = PHAssetCollection.fetchAssetCollectionsContaining(self, with: .album, options: nil)
        result.enumerateObjects { collection, _, _ in
            names.append(collection.localizedTitle ?? "Album")
        }
        return names
    }
}
