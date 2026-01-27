//
//  SongListView.swift
//  songbook
//
//  Created by acemavrick on 6/6/25.
//

import SwiftUI
import CoreData

// SongRowView, TagGroupView, AlphabetIndexView are now in Views/Shared/

struct SortPicker: View {
    @Binding var sortByBinding: SongListViewModel.SortOption
    
    var body: some View {
        HStack {
            Text("Sort By:")
            Picker("", selection: $sortByBinding) {
                ForEach(SongListViewModel.SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue.capitalized).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct SongSection: View {
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
                } // end NavigationLink
            } // end ForEach
        } // end Section
    }
}

struct SongListView: View {
    @StateObject var viewModel: SongListViewModel
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(viewModel.sortedSectionKeys, id: \.self) { sectionKey in
                        SongSection(sectionKey: sectionKey, viewModel: viewModel)
                            .id(sectionKey)
                    } // end ForEach
                    
                    if (viewModel.songs.isEmpty) {
                        Text("No songs found.")
                    }
                } // end list
                .searchable(text: $viewModel.searchText)
                .overlay(
                    AlphabetIndexView(keys: viewModel.sortedSectionKeys, proxy: proxy)
                )
            }
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .navigationTitle(viewModel.category?.name ?? "All Songs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 5) {
                    SortPicker(sortByBinding: $viewModel.sortBy)
                    
                    Button {
                        withAnimation {
                            viewModel.toggleOnlyFavorites()
                        }
                    } label: {
//                        if viewModel.onlyFavorites {
//                            Label("Show All", systemImage: "chevron.compact.down")
//                        } else {
//                            Label("Show Favorites", systemImage: "star.fill")
//                        }
                        Image(systemName: viewModel.onlyFavorites ? "star.square.on.square.fill" : "star.square.on.square")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .labelStyle(.titleAndIcon)
                }
            } // end item
        } // end toolbar
    }
}

#Preview {
    SongListView(viewModel: PreviewSongListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
}
