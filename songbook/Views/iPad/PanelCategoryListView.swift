//
//  PanelCategoryListView.swift
//  songbook
//
//  Category list inside the floating navigation panel.
//

import SwiftUI

struct PanelCategoryListView: View {
    @ObservedObject var viewModel: CategoryListViewModel
    @Binding var navigationPath: NavigationPath
    @Environment(SyncManager.self) private var syncManager

    var body: some View {
        List {
            // all songs row
            Button {
                navigationPath.append("all")
            } label: {
                PanelCategoryRow(name: "All Songs", count: viewModel.totalSongs)
            }
            .buttonStyle(.plain)

            // category rows
            ForEach(viewModel.categories, id: \.self) { category in
                Button {
                    navigationPath.append(category)
                } label: {
                    PanelCategoryRow(name: category.name, count: viewModel.getSongCount(for: category))
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SyncStatusIndicator(syncManager: syncManager)
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

// MARK: - Panel Category Row

/// compact category row for the panel
struct PanelCategoryRow: View {
    let name: String?
    let count: Int?

    var body: some View {
        HStack {
            Text(name ?? "Unknown")
                .font(.body)
            Spacer()
            if let count = count {
                Text("\(count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .scaleEffect(0.7)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        PanelCategoryListView(
            viewModel: PreviewCategoryListViewModel(),
            navigationPath: .constant(NavigationPath())
        )
    }
    .frame(width: 320)
    .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
    .environment(SyncManager.shared)
}
