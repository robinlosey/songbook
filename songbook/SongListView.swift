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
                    .foregroundColor(song.isFavorite ? .yellow : .gray)
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
                ForEach(viewModel.songs) { song in
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
            .navigationTitle(viewModel.category?.name ?? "All Songs")
        }
    }
}

#Preview {
    SongListView(viewModel: PreviewSongListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
}
