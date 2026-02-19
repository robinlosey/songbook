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

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isiPad: Bool { sizeClass == .regular }

    private var showControls: Bool {
        controlsVisible ?? !hideAudioByDefault
    }

    // only show audio toggle if audio is potentially available
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
            // pdf viewer (full screen)
            PDFViewer(forSong: song.filename ?? "Unknown")
                .ignoresSafeArea(.all)
                .onTapGesture {
                    if !isiPad {
                        withAnimation {
                            barsVisible.toggle()
                        }
                    }
                }
            
            // audio controls overlay (iPhone only)
            if !isiPad && showControls && barsVisible {
                AudioPlayerOverlay(song: song)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            if !isiPad {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        // favorite button
                        Button(action: toggleFavoriteAction) {
                            Image(systemName: song.isFavorite ? "star.fill" : "star")
                                .symbolEffect(.bounce, value: song.isFavorite)
                                .foregroundStyle(song.isFavorite ? AppColor.color1 : .primary)
                        }
                        
                        // audio controls toggle
                        if showAudioToggle {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    controlsVisible = !showControls
                                }
                            } label: {
                                Image(systemName: showControls ? "music.note" : "music.note.list")
                            }
                        }
                        
                        // info button
                        Button {
                            showInfoPopover = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                }
            }
        }
        .toolbar(barsVisible ? .visible : .hidden, for: .navigationBar)
        .sheet(isPresented: $showInfoPopover) {
            SongInfoPopover(song: song)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
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
