//
//  PanelSongListView.swift
//  songbook
//
//  Song list inside the floating navigation panel.
//

import SwiftUI

struct PanelSongListView: View {
    let category: Category?
    @Binding var selectedSong: Song?
    @Binding var showPanel: Bool

    @StateObject private var viewModel: SongListViewModel

    init(category: Category?, selectedSong: Binding<Song?>, showPanel: Binding<Bool>) {
        self.category = category
        self._selectedSong = selectedSong
        self._showPanel = showPanel
        self._viewModel = StateObject(wrappedValue: SongListViewModel(category: category))
    }

    var body: some View {
        List {
            ForEach(viewModel.sortedSectionKeys, id: \.self) { sectionKey in
                Section(header: Text(sectionKey)) {
                    ForEach(viewModel.sectionedSongs[sectionKey] ?? []) { song in
                        Button {
                            selectedSong = song
                            // optionally close panel after selection
                            // withAnimation { showPanel = false }
                        } label: {
                            PanelSongRow(
                                song: song,
                                isSelected: selectedSong?.objectID == song.objectID
                            ) {
                                withAnimation {
                                    viewModel.toggleFavorite(for: song)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if viewModel.songs.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    viewModel.onlyFavorites ? "No Favorites" : "No Songs",
                    systemImage: "music.note",
                    description: Text("No songs in this category")
                )
            }
        }
        .listStyle(.plain)
        .navigationTitle(category?.name ?? "All Songs")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    SortMenuButton(sortBy: $viewModel.sortBy)
                    FavoritesFilterButton(isActive: viewModel.onlyFavorites) {
                        withAnimation {
                            viewModel.toggleOnlyFavorites()
                        }
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

// MARK: - Panel Song Row

/// compact song row for the panel with selection highlight
struct PanelSongRow: View {
    @ObservedObject var song: Song
    let isSelected: Bool
    let toggleFavorite: () -> Void
    
    @AppStorage("showCategoryTags") private var showTags = true
    
    private var sortedCategories: [Category] {
        (song.categories?.allObjects as? [Category])?.sorted {
            ($0.name ?? "") < ($1.name ?? "")
        } ?? []
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Button(action: toggleFavorite) {
                Image(systemName: song.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(song.isFavorite ? Color.accentColor : .secondary)
                    .font(AppFont.subheadline)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title ?? "Untitled")
                    .font(AppFont.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                Text(song.artist ?? "Unknown")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if showTags && !sortedCategories.isEmpty {
                    TagFlowView(tags: sortedCategories)
                        .padding(.top, 2)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(AppFont.caption)
                    .foregroundStyle(.accent)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                    .fill(Color.accentColor.opacity(0.1))
                    .padding(.horizontal, -8)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PanelSongListView(
            category: nil,
            selectedSong: .constant(nil),
            showPanel: .constant(true)
        )
    }
    .frame(width: 320)
    .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
}
