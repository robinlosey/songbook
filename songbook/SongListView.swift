//
//  SongListView.swift
//  songbook
//
//  Created by acemavrick on 6/6/25.
//

import SwiftUI
import CoreData

struct TagGroupView: View {
    var tags: [Category]
    
    var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            LazyHStack(spacing: 8) {
                ForEach(tags) { tag in
                    Text(tag.name ?? "Untitled Tag")
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.accent.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

struct SongRowView: View {
    @ObservedObject var song: Song
    var toggleFavoriteAction: () -> Void
    
    var body: some View {
        HStack {
            Button(action: toggleFavoriteAction) {
                Image(systemName: song.isFavorite ? "star.fill" : "star")
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title ?? "Untitled Song")
                    .font(.headline)
                Text(song.artist ?? "Unknown Artist")
                    .font(.subheadline)
                Text(song.first_line ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Tag Groups
                ScrollView(.horizontal, showsIndicators: false) {
                    TagGroupView(tags: (song.categories?.allObjects as? [Category]) ?? [])
                }
            }
        }
    }
}

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
        List {
            ForEach(viewModel.sortedSectionKeys, id: \.self) { sectionKey in
                SongSection(sectionKey: sectionKey, viewModel: viewModel)
            } // end ForEach
        } // end list
        .navigationTitle(viewModel.category?.name ?? "All Songs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 10) {
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
                    .buttonStyle(.plain)
                    .labelStyle(.titleAndIcon)
                    .padding(.vertical, 20)
                }
            } // end item
        } // end toolbar
    }
}

#Preview {
    SongListView(viewModel: PreviewSongListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
}
