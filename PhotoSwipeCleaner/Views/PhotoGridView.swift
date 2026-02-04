import SwiftUI
import Photos

struct PhotoGridView: View {
    @EnvironmentObject var viewModel: PhotoCleanupViewModel
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(viewModel.photos) { photo in
                    PhotoGridCell(photo: photo)
                }
            }
        }
    }
}

struct PhotoGridCell: View {
    let photo: PhotoItem
    @State private var thumbnail: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.width)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            Task {
                thumbnail = await PhotoService.shared.getThumbnail(
                    for: photo,
                    size: CGSize(width: 200, height: 200)
                )
            }
        }
    }
}

#Preview {
    PhotoGridView()
        .environmentObject(PhotoCleanupViewModel())
        .frame(width: 400, height: 600)
}