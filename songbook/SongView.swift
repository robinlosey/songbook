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

struct ClusterButtonStyle: ButtonStyle {
    var isCapsule: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledToFill()
            .padding(15)
            .background {
                if isCapsule {
                    Capsule()
                        .fill(.thinMaterial)
                    Capsule()
                        .fill(.accent.opacity(0.3))
                } else {
                    Circle()
                        .fill(.thinMaterial)
                    Circle()
                        .fill(.accent.opacity(0.3))
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .overlay {
                if isCapsule {
                    Capsule()
                        .stroke()
                        .opacity(0.3)
                } else {
                    Circle()
                        .stroke()
                        .opacity(0.3)
                }
            }
    }
}

// overlay with the song info
struct AudioInfoOverlay: View {
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    @State private var sliderValue: Double = 0
    @State private var isSeeking = false
    
    var body: some View {
        // simple progressView of progress of the song
        VStack {
            Spacer()
            VStack {
                Slider(
                    value: $sliderValue,
                    in: 0...audioPlayer.duration,
                    onEditingChanged: { editing in
                        isSeeking = editing
                        if !editing {
                            audioPlayer.seek(to: sliderValue)
                        }
                    }
                )
                HStack {
                    Text("\(audioPlayer.currentTime.formattedTime())")
                        .font(.headline)
                    
                    Spacer()
                    
                    // play/pause, ±5 sec
                    HStack(alignment: .center, spacing: 19) {
                        Button {
                            audioPlayer.skipForward(by: -5.0)
                        } label: {
                            Image(systemName: "gobackward.5")
                        }
                        
                        Button {
                            audioPlayer.togglePlayPause()
                        } label: {
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        }
                        .font(.title)
                        
                        Button {
                            audioPlayer.skipForward(by: 5.0)
                        } label: {
                            Image(systemName: "goforward.5")
                        }
                    }
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
        .onAppear {
            sliderValue = audioPlayer.currentTime
        }
        .onChange(of: audioPlayer.currentTime) {
            if !isSeeking {
                withAnimation {
                    sliderValue = audioPlayer.currentTime
                }
            }
        }
    }
}

struct ButtonCluster: View {
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    @ObservedObject var song: Song
    var toggleFavoriteAction: () -> Void
    var controlsVisible: Binding<Bool>
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggleFavoriteAction) {
                Image(systemName: song.isFavorite ? "star.fill" : "star")
                    .font(.subheadline)
            }

            Button{
                withAnimation {
                    controlsVisible.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "music.note")
                    Image(systemName: controlsVisible.wrappedValue ? "eye.slash" : "eye")
                }
                .font(.headline)
            }
        }
        .buttonStyle(ClusterButtonStyle())
        .padding()
    }
}

struct SongView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    @ObservedObject var song: Song
    @State private var controlsVisible = true
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
                    ButtonCluster(song: song, toggleFavoriteAction: toggleFavoriteAction, controlsVisible: $controlsVisible)
                }
                
                // to push top bar to the top
                Spacer()
            }
            
            AudioInfoOverlay()
                .opacity(controlsVisible ? 1 : 0)
        } // end zstack
//        .toolbar {
//            ToolbarItem(placement: .topBarTrailing) {
//                ButtonCluster(song: song, toggleFavoriteAction: toggleFavoriteAction)
//            }
//        }
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
