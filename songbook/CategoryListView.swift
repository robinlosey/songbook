//
//  CategoryListView.swift
//  songbook
//
//  Created by acemavrick on 6/7/25.
//

import SwiftUI
import CoreData


struct CategoryRowView: View {
    let name: String?
    let count: Int?  // nil means loading

    var body: some View {
        HStack {
            Text(name ?? "Unknown Category")
                .font(.headline)
            Spacer()
            if let count = count {
                Text("\(count) Songs")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                // Show spinner while loading
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 20, height: 20)
            }
        }
        .padding()
    }
}

struct CategoryListView: View {
    @StateObject var viewModel: CategoryListViewModel
    @Environment(SyncManager.self) private var syncManager

    private var isSyncing: Bool {
        switch syncManager.state {
        case .idle, .complete, .failed: return false
        default: return true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    SongListView(viewModel: SongListViewModel())
                } label: {
                    CategoryRowView(name: "All Songs", count: viewModel.totalSongs)
                }
                ForEach(viewModel.categories, id: \.self) { category in
                    NavigationLink {
                        SongListView(viewModel: SongListViewModel(category: category))
                    } label: {
                        CategoryRowView(name: category.name, count: viewModel.getSongCount(for: category))
                    }
                }
            }
            .navigationTitle("Categories")
            .safeAreaInset(edge: .bottom) {
                SyncStatusBar(syncManager: syncManager, isSyncing: isSyncing)
            }
            .onChange(of: syncManager.state) { oldState, newState in
                if case .complete = newState {
                    viewModel.fetchCategories()
                    viewModel.getTotalSongs()
                }
            }
        }
    }
}

// status bar as a separate view to avoid toolbar issues
struct SyncStatusBar: View {
    let syncManager: SyncManager
    let isSyncing: Bool

    var body: some View {
        HStack {
            Text("v\(syncManager.currentVersion)")

            Text("[\(stateText)]")
                .bold()

            Spacer()

            // status icon
            Group {
                switch syncManager.state {
                case .idle:
                    Image(systemName: "minus")
                case .checking, .downloading, .parsing, .building, .verifying:
                    Image(systemName: "circle.dotted.circle")
                case .complete:
                    Image(systemName: "checkmark")
                case .failed:
                    Image(systemName: "exclamationmark.triangle")
                }
            }

            Button {
                SyncManager.requestSync()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(isSyncing)
            .buttonStyle(.bordered)
        }
        .font(.footnote)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var stateText: String {
        switch syncManager.state {
        case .idle: return "idle"
        case .checking: return "checking"
        case .downloading: return "downloading"
        case .parsing: return "parsing"
        case .building: return "building"
        case .verifying: return "verifying"
        case .complete: return "complete"
        case .failed(let msg): return "failed: \(msg)"
        }
    }
}

#Preview {
    CategoryListView(viewModel: PreviewCategoryListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
        .environment(SyncManager.shared)
}
