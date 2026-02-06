import SwiftUI

struct StatusView: View {
    @EnvironmentObject var viewModel: PhotoSwipeViewModel

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.gray.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    StatCard(title: "Kept", value: "\(viewModel.keptCount)", color: .green, icon: "heart.fill")
                    StatCard(title: "Favorited", value: "\(viewModel.favoritedCount)", color: .yellow, icon: "star.fill")
                    StatCard(title: "Deleted", value: "\(viewModel.deletedCount)", color: .red, icon: "trash.fill")
                    StatCard(title: "Space Saved", value: formatBytes(viewModel.savedSpace), color: .blue, icon: "internaldrive.fill")
                    StatCard(title: "Pending Delete", value: "\(viewModel.pendingDeletions.count)", color: .orange, icon: "clock.fill")

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Current Category")
                            .foregroundColor(.gray)
                            .font(.caption)
                        Label(viewModel.selectedCategory.rawValue, systemImage: viewModel.selectedCategory.icon)
                            .foregroundColor(.white)
                            .font(.headline)
                        Text(viewModel.remainingText)
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scan Progress")
                            .foregroundColor(.gray)
                            .font(.caption)

                        ProgressView(value: viewModel.scanProgress)
                            .tint(.blue)

                        Text("\(viewModel.scanScannedCount) / \(viewModel.scanTotalCount)")
                            .foregroundColor(.white)
                            .font(.subheadline)

                        HStack(spacing: 10) {
                            Button(viewModel.isScanRunning ? (viewModel.isScanPaused ? "Resume" : "Pause") : "Start Scan") {
                                if viewModel.isScanRunning {
                                    viewModel.pauseOrResumeScan()
                                } else {
                                    viewModel.startForegroundScan()
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Detect Duplicates") {
                                viewModel.detectExactDuplicates()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.scanScannedCount == 0)
                        }

                        NavigationLink {
                            DuplicateCleanupView()
                        } label: {
                            HStack {
                                Image(systemName: "square.stack.3d.down.right")
                                Text("Open Duplicate Cleanup")
                            }
                            .foregroundColor(.white)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.8))
                            .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Cleaning Status")
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes <= 0 { return "0 KB" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
    }
}
