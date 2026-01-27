//
//  iPadSongControlsMenu.swift
//  songbook
//
//  Unified popover menu for iPad containing Song Info, Audio Controls, and Settings.
//

import SwiftUI

struct iPadSongControlsMenu: View {
    @ObservedObject var song: Song
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    @Binding var showSettings: Bool
    @Binding var isPresented: Bool
    var toggleFavoriteAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    // 1. Song Identity & Favorite
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.title ?? "Untitled")
                                .font(AppFont.title3.weight(.bold))
                                .foregroundStyle(.primary)
                            
                            Text(song.artist ?? "Unknown Artist")
                                .font(AppFont.body)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: toggleFavoriteAction) {
                            Image(systemName: song.isFavorite ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundStyle(song.isFavorite ? AppColor.primary : .secondary)
                                .padding(12)
                                .background(AppColor.primary.opacity(song.isFavorite ? 0.1 : 0.05))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Divider()
                    
                    // 2. Audio Controls Section
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Label("Audio", systemImage: "music.note")
                            .font(AppFont.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                        
                        iPadAudioControlSection(song: song)
                    }
                    
                    Divider()
                    
                    // 3. Metadata / Info Section
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Label("Information", systemImage: "info.circle")
                            .font(AppFont.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                        
                        if let firstLine = song.first_line, !firstLine.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("First Line")
                                    .font(AppFont.caption)
                                    .foregroundStyle(.tertiary)
                                Text("“\(firstLine)”")
                                    .font(AppFont.body.italic())
                            }
                        }
                        
                        if let categories = song.categories?.allObjects as? [Category], !categories.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Categories")
                                    .font(AppFont.caption)
                                    .foregroundStyle(.tertiary)
                                TagFlowView(tags: categories.sorted { ($0.name ?? "") < ($1.name ?? "") })
                            }
                        }
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // 4. Settings Footer
            Button {
                isPresented = false
                // Small delay to ensure popover dismisses before sheet presents
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showSettings = true
                }
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("App Settings")
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(20)
                .background(Color.primary.opacity(0.03))
            }
            .buttonStyle(.plain)
        }
        .frame(width: 380)
        .frame(maxHeight: 650)
    }
}

// MARK: - Audio Control Section (Adapted for Popover)

struct iPadAudioControlSection: View {
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    @ObservedObject var song: Song
    @State private var sliderValue: Double = 0
    @State private var isSeeking = false

    var body: some View {
        VStack(spacing: 16) {
            switch audioPlayer.audioAvailability {
            case .available:
                playbackControls
            case .downloadable:
                downloadButton
            case .downloading:
                HStack {
                    ProgressView()
                    Text("Downloading audio...")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                }
            case .notFound:
                Text("No audio available for this song")
                    .font(AppFont.subheadline)
                    .foregroundStyle(.secondary)
            case .unknown:
                ProgressView().controlSize(.small)
            }
        }
        .onAppear { sliderValue = audioPlayer.currentTime }
        .onChange(of: audioPlayer.currentTime) { if !isSeeking { sliderValue = audioPlayer.currentTime } }
    }
    
    private var playbackControls: some View {
        VStack(spacing: 12) {
            Slider(value: $sliderValue, in: 0...max(audioPlayer.duration, 0.01)) { editing in
                isSeeking = editing
                if !editing { audioPlayer.seek(to: sliderValue) }
            }
            .tint(AppColor.primary)

            HStack {
                Text(audioPlayer.currentTime.formattedTime())
                Spacer()
                HStack(spacing: 30) {
                    Button { audioPlayer.skipForward(by: -5) } label: { Image(systemName: "gobackward.5") }
                    Button { audioPlayer.togglePlayPause() } label: {
                        Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(AppColor.primary)
                    }
                    Button { audioPlayer.skipForward(by: 5) } label: { Image(systemName: "goforward.5") }
                }
                .font(.title2)
                Spacer()
                Text("-\(audioPlayer.timeLeft.formattedTime())")
            }
            .font(AppFont.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var downloadButton: some View {
        Button {
            Task { await audioPlayer.downloadAndSetup(song: song) }
        } label: {
            Label("Download Audio", systemImage: "arrow.down.circle")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppColor.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .foregroundStyle(AppColor.primary)
    }
}
