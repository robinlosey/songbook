//
//  SongView.swift
//  songbook
//
//  Created by acemavrick on 6/5/25.
//

import SwiftUI

struct CategoryTag: View {
    // idea: make this link to the song list for the category
    let category: Category?
    var body: some View {
        Text(category?.name ?? "Unknown Category")
            .font(.caption)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 15)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.accentColor.opacity(0.1))
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

struct SongView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    @ObservedObject var song: Song
    var toggleFavoriteAction: () -> Void
    
    private var sortedCategories: [Category] {
        guard let categories = song.categories as? Set<Category> else { return [] }
        return categories.sorted { $0.name ?? "" < $1.name ?? "" }
    }
    
    var body: some View {
        ZStack {
            PDFViewer(forSong: song.filename ?? "Unknown")
                .ignoresSafeArea(.all)
            
            VStack {
                HStack {
                    // category tags
//                    HStack {
//                        ForEach(sortedCategories, id: \.self) { category in
//                            CategoryTag(category: category)
//                        }
//                    }
//                    .padding()
                    
                    Spacer()
                    
                    // button
                    HStack(spacing: 20) {
                        Button(action: toggleFavoriteAction) {
                            Image(systemName: song.isFavorite ? "star.fill" : "star")
                        }
                        
                        Button{
                            audioPlayer.togglePlayPause()
                        } label: {
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                    .controlGroupStyle(.navigation)
                    .background {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.accentColor.opacity(0.1))
                    }
                    .overlay {
                        Divider()
                            .padding(.vertical, 5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .padding()
                }
                
                // to push top bar to the top
                Spacer()
            }
        } // end zstack
        .onAppear {
            audioPlayer.setup(song: song)
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }// end body
}

#Preview {
    SongView(song: Song(entity: Song.entity(), insertInto: DataManager.preview.container.viewContext)) {
        print("Toggle favorite action triggered")
    }
}
