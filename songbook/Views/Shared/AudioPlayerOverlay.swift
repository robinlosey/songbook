//
//  AudioPlayerOverlay.swift
//  songbook
//
//  Extracted from SongView - audio player controls overlay and toolbar buttons.
//

import SwiftUI

// MARK: - Time Formatting

extension TimeInterval {
    func formattedTime() -> String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%2d:%02d", minutes, seconds)
    }
}

// MARK: - Glass Button Style

/// custom button style with glass material background
struct ClusterButtonStyle: ButtonStyle {
    var isCapsule: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledToFill()
            .padding(12)
            .background {
                if isCapsule {
                    Capsule()
                        .fill(.thinMaterial)
                    Capsule()
                        .fill(.accent.opacity(0.2))
                } else {
                    Circle()
                        .fill(.thinMaterial)
                    Circle()
                        .fill(.accent.opacity(0.2))
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

// MARK: - Audio Info Overlay

/// bottom overlay showing audio controls based on availability state
struct AudioInfoOverlay: View {
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    @ObservedObject var song: Song
    @State private var sliderValue: Double = 0
    @State private var isSeeking = false

    var body: some View {
        VStack {
            Spacer()

            switch audioPlayer.audioAvailability {
            case .available:
                audioPlayerControls
            case .downloadable:
                downloadButton
            case .downloading:
                downloadingIndicator
            case .notFound:
                noAudioMessage
            case .unknown:
                checkingIndicator
            }
        }
        .padding()
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

    // MARK: - Audio Player Controls

    private var audioPlayerControls: some View {
        VStack {
            HStack {
                Slider(
                    value: $sliderValue,
                    in: 0...max(audioPlayer.duration, 0.01),
                    onEditingChanged: { editing in
                        isSeeking = editing
                        if !editing {
                            audioPlayer.seek(to: sliderValue)
                        }
                    }
                )

                Button {
                    audioPlayer.toggleRepeat()
                } label: {
                    Image(audioPlayer.repeatMode == .off ? "custom.repeat.1.rectangle" : "custom.repeat.1.rectangle.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
            }
            HStack {
                Text("\(audioPlayer.currentTime.formattedTime())")
                    .font(.headline)

                Spacer()

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

                    Button {
                        audioPlayer.skipForward(by: 5.0)
                    } label: {
                        Image(systemName: "goforward.5")
                    }
                }
                .buttonStyle(.plain)
                .font(.title)

                Spacer()

                Text("-\(audioPlayer.timeLeft.formattedTime())")
                    .font(.headline)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(.thinMaterial)
            RoundedRectangle(cornerRadius: 15)
                .fill(.accent.opacity(0.1))
        }
    }

    // MARK: - Download Button

    private var downloadButton: some View {
        Button {
            Task {
                await audioPlayer.downloadAndSetup(song: song)
            }
        } label: {
            Label("Download Audio", systemImage: "arrow.down.circle")
                .font(.headline)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(.thinMaterial)
        }
    }

    // MARK: - Downloading Indicator

    private var downloadingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Downloading audio...")
                .font(.headline)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(.thinMaterial)
            RoundedRectangle(cornerRadius: 15)
                .fill(.accent.opacity(0.1))
        }
    }

    // MARK: - No Audio Message

    private var noAudioMessage: some View {
        Label("No audio available", systemImage: "speaker.slash")
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 15)
                    .fill(.thinMaterial)
            }
    }

    // MARK: - Checking Indicator

    private var checkingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Checking audio...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(.thinMaterial)
        }
    }
}

// MARK: - Button Cluster (Toolbar)

/// toolbar button cluster for favorite toggle and audio controls visibility
struct ButtonCluster: View {
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    @ObservedObject var song: Song
    var toggleFavoriteAction: () -> Void
    var controlsVisible: Binding<Bool>

    // only show audio toggle when audio is potentially available
    private var showAudioToggle: Bool {
        switch audioPlayer.audioAvailability {
        case .available, .downloadable, .downloading, .unknown:
            return true
        case .notFound:
            return false
        }
    }

    var body: some View {
        HStack(spacing: 15) {
            Button(action: toggleFavoriteAction) {
                Image(systemName: song.isFavorite ? "star.fill" : "star")
                    .padding(8)
                    .contentShape(Rectangle())
            }

            if showAudioToggle {
                Button {
                    withAnimation {
                        controlsVisible.wrappedValue.toggle()
                    }
                } label: {
                    Group {
                        if controlsVisible.wrappedValue {
                            Image(systemName: "music.note")
                        } else {
                            Image("custom.music.note.slash")
                        }
                    }
                    .padding(8)
                    .contentShape(Rectangle())
                }
            }
        }
        .font(.title2)
    }
}

// MARK: - Category Tag

/// single category tag with glass styling
struct CategoryTag: View {
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
