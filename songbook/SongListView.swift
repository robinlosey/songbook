//
//  SongListView.swift
//  songbook
//
//  Created by acemavrick on 6/6/25.
//

import SwiftUI
import CoreData

struct SongRowView: View {
    @ObservedObject var song: Song
    var toggleFavoriteAction: () -> Void
    
    var body: some View {
        HStack {
            Button(action: toggleFavoriteAction) {
                Image(systemName: song.isFavorite ? "star.fill" : "star")
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading) {
                Text(song.title ?? "Untitled Song")
                    .font(.headline)
                Text(song.artist ?? "Unknown Artist")
                    .font(.subheadline)
                Text(song.first_line ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct SongListView: View {
    @StateObject var viewModel: SongListViewModel
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.sortedSectionKeys, id: \.self) { sectionKey in
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
                } // end ForEach
            } // end list
            .navigationTitle(viewModel.category?.name ?? "All Songs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Text("Sort By:")
                        Picker(selection: $viewModel.sortBy) {
                            ForEach(SongListViewModel.SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue.capitalized).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } // end ToolbarItem
            }// end toolbar
        }// end NavigationStack
    } // end body
}

#Preview {
    SongListView(viewModel: PreviewSongListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
}
