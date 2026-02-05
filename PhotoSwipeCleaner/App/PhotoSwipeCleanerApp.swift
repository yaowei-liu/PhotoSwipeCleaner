import SwiftUI

@main
struct PhotoSwipeCleanerApp: App {
    @StateObject private var photoSwipeViewModel = PhotoSwipeViewModel()
    
    var body: some Scene {
        WindowGroup {
            PhotoSwipeView()
                .environmentObject(photoSwipeViewModel)
        }
    }
}