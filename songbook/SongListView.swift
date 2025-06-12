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
        NavigationStack {
            List {
                ForEach(viewModel.sortedSectionKeys, id: \.self) { sectionKey in
                    SongSection(sectionKey: sectionKey, viewModel: viewModel)
                } // end ForEach
            } // end list
            .navigationTitle(viewModel.category?.name ?? "All Songs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SortPicker(sortByBinding: $viewModel.sortBy)
                } // end ToolbarItem
            }// end toolbar
            
        }// end NavigationStack
    } // end body
}

#Preview {
    SongListView(viewModel: PreviewSongListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
}
