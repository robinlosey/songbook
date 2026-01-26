//
//  iOSSongListView.swift
//  songbook
//
//  iPhone song list with dropdown sort menu and improved favorites filter.
//

import SwiftUI
import CoreData

struct iOSSongListView: View {
    @StateObject var viewModel: SongListViewModel

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(viewModel.sortedSectionKeys, id: \.self) { sectionKey in
                        iOSSongSection(sectionKey: sectionKey, viewModel: viewModel)
                            .id(sectionKey)
                    }

                    if viewModel.songs.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView(
                            viewModel.onlyFavorites ? "No Favorites" : "No Songs",
                            systemImage: viewModel.onlyFavorites ? "star.slash" : "music.note",
                            description: Text(viewModel.onlyFavorites
                                ? "Star some songs to see them here"
                                : "No songs found in this category")
                        )
                    }
                }
                .searchable(text: $viewModel.searchText, prompt: "Search songs...")
                .overlay(alignment: .trailing) {
                    if !viewModel.sortedSectionKeys.isEmpty {
                        AlphabetIndexView(keys: viewModel.sortedSectionKeys, proxy: proxy)
                    }
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .navigationTitle(viewModel.category?.name ?? "All Songs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    SortMenuButton(sortBy: $viewModel.sortBy)
                    FavoritesFilterButton(isActive: viewModel.onlyFavorites) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.toggleOnlyFavorites()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Song Section

private struct iOSSongSection: View {
    let sectionKey: String
    @ObservedObject var viewModel: SongListViewModel

    var body: some View {
        Section(header: Text(sectionKey)) {
            ForEach(viewModel.sectionedSongs[sectionKey] ?? []) { song in
                NavigationLink {
                    SongView(song: song) {
                        withAnimation {
                            viewModel.toggleFavorite(for: song)
                        }
                    }
                } label: {
                    SongRowView(song: song) {
                        withAnimation {
                            viewModel.toggleFavorite(for: song)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sort Menu Button (replaces segmented picker)

struct SortMenuButton: View {
    @Binding var sortBy: SongListViewModel.SortOption

    var body: some View {
        Menu {
            Picker("Sort by", selection: $sortBy) {
                ForEach(SongListViewModel.SortOption.allCases) { option in
                    Label(option.rawValue.capitalized, systemImage: iconFor(option))
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body)
        }
    }

    private func iconFor(_ option: SongListViewModel.SortOption) -> String {
        switch option {
        case .title: return "textformat"
        case .artist: return "person"
        case .firstLine: return "text.quote"
        }
    }
}

// MARK: - Favorites Filter Button (improved active state)

struct FavoritesFilterButton: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? "star.fill" : "star")
                .font(.body)
                .foregroundStyle(isActive ? Color.accentColor : .primary)
                .padding(8)
                .background {
                    if isActive {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Show all songs" : "Show favorites only")
    }
}

#Preview {
    NavigationStack {
        iOSSongListView(viewModel: PreviewSongListViewModel())
    }
    .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
    .environmentObject(AudioPlayerViewModel())
}
