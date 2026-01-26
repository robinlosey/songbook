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

// MARK: - Placeholder Views (to be implemented in Phase 2 & 3)

/// placeholder for iPad layout - will be replaced with floating panel design
struct iPadRootView: View {
    @StateObject var viewModel: CategoryListViewModel

    var body: some View {
        // for now, use the same view as iPhone
        // Phase 3 will implement the floating panel design
        CategoryListView(viewModel: viewModel)
    }
}

/// placeholder for iPhone layout - will be replaced with polished stack navigation
struct iOSRootView: View {
    @StateObject var viewModel: CategoryListViewModel

    var body: some View {
        // for now, use the existing view
        // Phase 2 will implement the polished iPhone navigation
        CategoryListView(viewModel: viewModel)
    }
}

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
