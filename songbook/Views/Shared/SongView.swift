//
//  SongView.swift
//  songbook
//
//  Main song view displaying PDF and audio controls.
//

import SwiftUI

struct SongView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    @AppStorage("hideAudioControlsByDefault") private var hideAudioByDefault = false
    @ObservedObject var song: Song
    var toggleFavoriteAction: () -> Void

    @State private var controlsVisible: Bool?  // nil until initialized
    @State private var barsVisible = true
    @State private var showInfoPopover = false

    private var showControls: Bool {
        controlsVisible ?? !hideAudioByDefault
    }
    
    // Only show audio toggle if audio is potentially available
    private var showAudioToggle: Bool {
        switch audioPlayer.audioAvailability {
        case .available, .downloadable, .downloading, .unknown:
            return true
        case .notFound:
            return false
        }
    }
    
    var body: some View {
        ZStack {
            // PDF Viewer (Full Screen)
            PDFViewer(forSong: song.filename ?? "Unknown")
                .ignoresSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        barsVisible.toggle()
                    }
                }
            
            // Audio Controls Overlay
            if showControls && barsVisible {
                AudioPlayerOverlay(song: song)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    // Favorite Button
                    Button(action: toggleFavoriteAction) {
                        Image(systemName: song.isFavorite ? "star.fill" : "star")
                            .symbolEffect(.bounce, value: song.isFavorite)
                    }
                    
                    // Audio Controls Toggle
                    if showAudioToggle {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                controlsVisible = !showControls
                            }
                        } label: {
                            Image(systemName: showControls ? "music.note" : "music.note.list")
                        }
                    }
                    
                    // Info Button
                    Button {
                        showInfoPopover = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .popover(isPresented: $showInfoPopover) {
                        SongInfoPopover(song: song)
                    }
                }
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
    NavigationStack {
        SongView(song: Song(entity: Song.entity(), insertInto: DataManager.preview.container.viewContext)) {
            print("Toggle favorite action triggered")
        }
    }
    .environmentObject(AudioPlayerViewModel())
}
