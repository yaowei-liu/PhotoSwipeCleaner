import SwiftUI

@main
struct PhotoSwipeCleanerApp: App {
    @StateObject private var photoCleanupVM = PhotoCleanupViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoCleanupVM)
        }
    }
}