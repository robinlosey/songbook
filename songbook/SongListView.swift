//
//  SongListView.swift
//  songbook
//
//  Created by Gemini Assistant on 6/6/25.
//

import SwiftUI
import CoreData

struct SongDetailView: View {
    var forSong: Song
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(forSong.title ?? "Untitled Song")
                .font(.title)
            Text(forSong.artist ?? "Unknown Artist")
                .font(.headline)
            Text(forSong.first_line ?? "")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("Filename: \(forSong.filename ?? "N/A")")
                .font(.caption)
            Text("Is Favorite: \(forSong.isFavorite ? "Yes" : "No")")
                .font(.caption)
        }
        .padding()
        .navigationTitle(forSong.title ?? "Song Details")
    }
}

struct SongListView: View {
    @StateObject var viewModel: SongListViewModel
    var previewMode: Bool = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.songs) { song in
                    NavigationLink {
                        if previewMode {
                            SongDetailView(forSong: song)
                        } else {
                            if let filename = song.filename, !filename.isEmpty {
                                PDFViewer(forSong: filename)
                            } else {
                                Text("No PDF available for this song.")
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(song.title ?? "Untitled Song")
                                    .font(.headline)
                                Text(song.artist ?? "Unknown Artist")
                                    .font(.subheadline)
                                Text(song.first_line ?? "")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            if song.isFavorite {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("All Songs")
        }
    }
}

#Preview {
    SongListView(viewModel: PreviewSongListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
}
