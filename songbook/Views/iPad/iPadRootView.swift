//
//  iPadRootView.swift
//  songbook
//
//  iPad root view with full-screen PDF and floating navigation panel.
//

import SwiftUI

struct iPadRootView: View {
    @AppStorage("appearance") private var appearance = "system"
    @ObservedObject var viewModel: CategoryListViewModel
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    @State private var showPanel = true
    @State private var selectedSong: Song?
    @State private var showSettings = false
    @State private var showSongControls = false
    @State private var showAudioOverlay = false

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MeshBackground()

            // full-screen PDF (or empty state)
            Group {
                if let song = selectedSong {
                    SongView(song: song) {
                        withAnimation {
                            song.isFavorite.toggle()
                            try? song.managedObjectContext?.save()
                        }
                    }
                } else {
                    iPadEmptyStateView(showPanel: $showPanel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // top-right controls - inline buttons instead of collapsed menu
            HStack(spacing: 10) {
                if let song = selectedSong {
                    // favorite toggle
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            song.isFavorite.toggle()
                            try? song.managedObjectContext?.save()
                        }
                    } label: {
                        Image(systemName: song.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(song.isFavorite ? AppColor.primary : .primary.opacity(0.7))
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial.opacity(0.9))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
                    }
                    .contentTransition(.symbolEffect(.replace))

                    // toggle audio overlay (only if audio available)
                    if audioPlayer.audioAvailability == .available {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showAudioOverlay.toggle()
                            }
                        } label: {
                            Image(systemName: showAudioOverlay ? "waveform.circle.fill" : "waveform.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(showAudioOverlay ? AppColor.primary : .primary.opacity(0.7))
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial.opacity(0.9))
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
                        }
                    }

                    // song info
                    Button {
                        showSongControls = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.7))
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial.opacity(0.9))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
                    }
                    .popover(isPresented: $showSongControls) {
                        iPadSongControlsMenu(
                            song: song,
                            showSettings: $showSettings,
                            isPresented: $showSongControls,
                            toggleFavoriteAction: {
                                withAnimation {
                                    song.isFavorite.toggle()
                                    try? song.managedObjectContext?.save()
                                }
                            }
                        )
                    }
                }

                // settings always visible
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial.opacity(0.9))
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            .padding(20)
            .zIndex(50)

            // dimming scrim when panel is open
            if showPanel {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showPanel = false
                        }
                    }
                .zIndex(20)
            }

            // navigation recall button - more visible floating button
            if !showPanel {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        showPanel = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Songs")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(AppColor.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial.opacity(0.9))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 2, y: 4)
                }
                .padding(.leading, 20)
                .padding(.top, 80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(30)
            }

            // floating navigation panel
            if showPanel {
                FloatingNavigationPanel(
                    viewModel: viewModel,
                    selectedSong: $selectedSong,
                    showPanel: $showPanel,
                    showSettings: $showSettings
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .zIndex(40)
            }

            // persistent audio overlay for practice
            if showAudioOverlay, let song = selectedSong, audioPlayer.audioAvailability == .available {
                iPadAudioOverlay(song: song, isShowing: $showAudioOverlay)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(45)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .preferredColorScheme(colorScheme)
        .gesture(
            // swipe from left edge to open panel
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.startLocation.x < 50 && value.translation.width > 50 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showPanel = true
                        }
                    }
                }
        )
    }
}

// MARK: - Empty State

struct iPadEmptyStateView: View {
    @Binding var showPanel: Bool

    var body: some View {
        ContentUnavailableView {
            Label("No Song Selected", systemImage: "music.note")
        } description: {
            Text("Select a song from the navigation panel to view it here")
        } actions: {
            Button("Open Navigation") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showPanel = true
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.primary)
        }
    }
}

// MARK: - Persistent Audio Overlay

/// floating audio bar for practice sessions - stays visible for easy scrubbing
struct iPadAudioOverlay: View {
    @ObservedObject var song: Song
    @Binding var isShowing: Bool
    @EnvironmentObject var audioPlayer: AudioPlayerViewModel
    @State private var sliderValue: Double = 0
    @State private var isSeeking = false

    var body: some View {
        HStack(spacing: 16) {
            // play/pause
            Button {
                audioPlayer.togglePlayPause()
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
                    .frame(width: 44, height: 44)
            }

            // time & scrubber
            VStack(spacing: 4) {
                Slider(value: $sliderValue, in: 0...max(audioPlayer.duration, 0.01)) { editing in
                    isSeeking = editing
                    if !editing { audioPlayer.seek(to: sliderValue) }
                }
                .tint(AppColor.primary)

                HStack {
                    Text(audioPlayer.currentTime.formattedTime())
                    Spacer()
                    Text("-\(audioPlayer.timeLeft.formattedTime())")
                }
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
            }

            // skip buttons
            HStack(spacing: 8) {
                Button { audioPlayer.skipForward(by: -5) } label: {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 16, weight: .medium))
                }
                Button { audioPlayer.skipForward(by: 5) } label: {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .foregroundStyle(.primary.opacity(0.7))

            // dismiss
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isShowing = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.primary.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
        .onAppear { sliderValue = audioPlayer.currentTime }
        .onChange(of: audioPlayer.currentTime) { _, newValue in
            if !isSeeking { sliderValue = newValue }
        }
    }
}

#Preview {
    iPadRootView(viewModel: PreviewCategoryListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
        .environment(SyncManager.shared)
        .environmentObject(AudioPlayerViewModel())
}
