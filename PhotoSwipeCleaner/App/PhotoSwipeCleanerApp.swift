import SwiftUI

@main
struct PhotoSwipeCleanerApp: App {
    @StateObject private var photoSwipeViewModel = PhotoSwipeViewModel()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                PhotoSwipeView()
                    .tabItem {
                        Label("Swipe", systemImage: "rectangle.stack.fill")
                    }

                StatusView()
                    .tabItem {
                        Label("Status", systemImage: "chart.bar.fill")
                    }
            }
            .environmentObject(photoSwipeViewModel)
        }
    }
}
