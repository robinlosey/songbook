//
//  iOSCategoryListView.swift
//  songbook
//
//  iPhone category list with minimal sync status and settings access.
//

import SwiftUI
import CoreData

struct iOSCategoryListView: View {
    @ObservedObject var viewModel: CategoryListViewModel
    @Environment(SyncManager.self) private var syncManager
    @Binding var showSettings: Bool

    var body: some View {
        List {
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    AppIconView()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    
                    Text("On Wings of the Soul")
                        .font(.system(.largeTitle, design: .serif))
                        .fontWeight(.medium)
                        .foregroundStyle(AppColor.primary)
                }
            }
            .listRowInsets(EdgeInsets(top:0, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)

            // all songs row
            Section {
                NavigationLink {
                    iOSSongListView(viewModel: SongListViewModel())
                } label: {
                    CategoryRowView(name: "All Songs", count: viewModel.totalSongs, isAllSongs: true)
                }

                // category rows
                ForEach(viewModel.categories, id: \.self) { category in
                    NavigationLink {
                        iOSSongListView(viewModel: SongListViewModel(category: category))
                    } label: {
                        CategoryRowView(name: category.name, count: viewModel.getSongCount(for: category))
                    }
                }
            }
            
            // app icon
            Section {
            }
        }
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SyncStatusIndicator(syncManager: syncManager)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .onChange(of: syncManager.state) { _, newState in
            if case .complete = newState {
                viewModel.fetchCategories()
                viewModel.getTotalSongs()
            }
        }
        
    }
}

// MARK: - Minimal Sync Status Indicator

/// minimal sync indicator: invisible when idle, subtle when syncing
struct SyncStatusIndicator: View {
    let syncManager: SyncManager
    @State private var showComplete = false

    private var isSyncing: Bool {
        switch syncManager.state {
        case .checking, .downloading, .parsing, .building, .verifying:
            return true
        default:
            return false
        }
    }

    private var isError: Bool {
        if case .failed = syncManager.state { return true }
        return false
    }

    var body: some View {
        Group {
            if isSyncing {
                // syncing: show progress indicator
                ProgressView()
                    .scaleEffect(0.8)
            } else if isError {
                // error: show warning with retry
                Button {
                    SyncManager.requestSync()
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColor.color5)
                }
            } else if showComplete {
                // briefly show checkmark after sync
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColor.color1)
                    .transition(.opacity)
            }
            // idle: show nothing
        }
        .animation(.easeInOut(duration: 0.2), value: isSyncing)
        .animation(.easeInOut(duration: 0.2), value: isError)
        .animation(.easeInOut(duration: 0.2), value: showComplete)
        .onChange(of: syncManager.state) { oldState, newState in
            // show checkmark briefly when sync completes
            if case .complete = newState {
                showComplete = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showComplete = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        iOSCategoryListView(
            viewModel: PreviewCategoryListViewModel(),
            showSettings: .constant(false)
        )
    }
    .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
    .environment(SyncManager.shared)
}
