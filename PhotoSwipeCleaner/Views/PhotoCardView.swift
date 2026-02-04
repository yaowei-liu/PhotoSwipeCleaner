import SwiftUI

struct PhotoCardView: View {
    let photo: PhotoItem
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0

    private let swipeThreshold: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color based on swipe direction
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.8), .orange.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .overlay {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("DELETE")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(-15))
                                    .padding()
                                Spacer()
                            }
                        }
                    }

                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.8), .mint.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .overlay {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("KEEP")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(15))
                                    .padding()
                                Spacer()
                            }
                        }
                    }

                // Photo thumbnail
                AsyncImage(url: nil) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: geometry.size.width - 20, height: geometry.size.height - 100)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(radius: 10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                        rotation = Double(value.translation.width / 20)
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if abs(value.translation.width) > swipeThreshold {
                                offset = CGSize(
                                    width: value.translation.width > 0 ? 500 : -500,
                                    height: 0
                                )
                            } else {
                                offset = .zero
                                rotation = 0
                            }
                        }
                    }
            )
        }
    }
}

#Preview {
    PhotoCardView(photo: PhotoItem(asset: PHAsset()))
        .frame(width: 300, height: 450)
        .padding()
}