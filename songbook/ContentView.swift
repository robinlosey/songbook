//
//  ContentView.swift
//  songbook
//
//  Root view that switches between iPhone and iPad layouts.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject var viewModel: CategoryListViewModel

    var body: some View {
        // switch layout based on device size class
        // .regular = iPad (or iPhone landscape on large devices)
        // .compact = iPhone
        if sizeClass == .regular {
            iPadRootView(viewModel: viewModel)
        } else {
            iOSRootView(viewModel: viewModel)
        }
    }
}

// iOSRootView is now in Views/iOS/iOSRootView.swift
// iPadRootView is now in Views/iPad/iPadRootView.swift

#Preview("iPhone") {
    ContentView(viewModel: PreviewCategoryListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
        .environment(SyncManager.shared)
        .environmentObject(AudioPlayerViewModel())
}

#Preview("iPad") {
    ContentView(viewModel: PreviewCategoryListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
        .environment(SyncManager.shared)
        .environmentObject(AudioPlayerViewModel())
}
