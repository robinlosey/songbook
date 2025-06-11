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

extension TimeInterval {
    func formattedTime() -> String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%2d:%02d", minutes, seconds)
    }
}

// overlay with the song info
struct AudioInfoOverlay: View {
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    
    var body: some View {
        // simple progressView of progress of the song
        VStack {
            Spacer()
            VStack {
                ProgressView(value: audioPlayer.currentTime, total: audioPlayer.duration)
                    .controlSize(.extraLarge)
                HStack {
                    Text("\(audioPlayer.currentTime.formattedTime())")
                        .font(.headline)
                    Spacer()
                    Text("-\(audioPlayer.timeLeft.formattedTime())")
                        .font(.headline)
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 15)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 15)
                    .fill(.accent.opacity(0.1))
            }
            .padding()
        }
    }
}

struct ButtonCluster: View {
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    var song: Song
    var toggleFavoriteAction: () -> Void
    
    var body: some View {
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
                    ButtonCluster(song: song, toggleFavoriteAction: toggleFavoriteAction)
                }
                
                // to push top bar to the top
                Spacer()
            }
            
            AudioInfoOverlay()
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
    .environmentObject(AudioPlayerViewModel())
}
