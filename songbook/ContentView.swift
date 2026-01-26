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

// MARK: - iPad Placeholder (to be implemented in Phase 3)

/// placeholder for iPad layout - will be replaced with floating panel design
struct iPadRootView: View {
    @ObservedObject var viewModel: CategoryListViewModel

    var body: some View {
        // for now, use the iPhone view
        // Phase 3 will implement the floating panel design
        iOSRootView(viewModel: viewModel)
    }
}

// iOSRootView is now in Views/iOS/iOSRootView.swift

#Preview("iPhone") {
    ContentView(viewModel: PreviewCategoryListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
        .environment(SyncManager.shared)
}

#Preview("iPad") {
    ContentView(viewModel: PreviewCategoryListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
        .environment(SyncManager.shared)
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch)"))
}
