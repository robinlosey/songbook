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
            Section {
                Button {
                    navigationPath.append("all")
                } label: {
                    PanelCategoryRow(name: "All Songs", count: viewModel.totalSongs, isAllSongs: true)
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
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .top) {
            HStack (spacing: 14){
                AppIconView()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                
                Text("On Wings of the Soul")
                    .font(.system(.largeTitle, design: .serif))
                    .fontWeight(.medium)
                    .foregroundStyle(AppColor.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
//        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
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
    var isAllSongs: Bool = false

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Text(name ?? "Unknown")
                .font(AppFont.body)

            Spacer()

            if let count = count {
                Text("\(count)")
                    .font(AppFont.subheadline)
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
