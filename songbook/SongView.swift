//
//  SongView.swift
//  songbook
//
//  Created by acemavrick on 6/5/25.
//

import SwiftUI

// AudioInfoOverlay, ButtonCluster, CategoryTag, ClusterButtonStyle, TimeInterval.formattedTime()
// are now in Views/Shared/AudioPlayerOverlay.swift

struct SongView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    @ObservedObject var song: Song
    @State private var controlsVisible = true
    @State private var barsVisible = true
    var toggleFavoriteAction: () -> Void
    
    private var sortedCategories: [Category] {
        guard let categories = song.categories as? Set<Category> else { return [] }
        return categories.sorted { $0.name ?? "" < $1.name ?? "" }
    }
    
    var body: some View {
        ZStack {
            PDFViewer(forSong: song.filename ?? "Unknown")
                .ignoresSafeArea(.all)
            
            AudioInfoOverlay(song: song)
                .opacity((controlsVisible && barsVisible) ? 1 : 0)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ButtonCluster(song: song, toggleFavoriteAction: toggleFavoriteAction, controlsVisible: $controlsVisible)
            }
        }
        .toolbar(barsVisible ? .visible : .hidden, for: .navigationBar)
        .onAppear {
            audioPlayer.setup(song: song)
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
}

#Preview {
    SongView(song: Song(entity: Song.entity(), insertInto: DataManager.preview.container.viewContext)) {
        print("Toggle favorite action triggered")
    }
    .environmentObject(AudioPlayerViewModel())
}
