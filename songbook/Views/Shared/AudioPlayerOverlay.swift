//
//  AudioPlayerOverlay.swift
//  songbook
//
//  Audio player controls overlay with glass styling.
//

import SwiftUI

// MARK: - Time Formatting

extension TimeInterval {
    func formattedTime() -> String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Player Overlay

/// bottom overlay showing audio controls based on availability state
struct AudioPlayerOverlay: View {
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .downloadable:
                downloadButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .downloading:
                downloadingIndicator
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .notFound:
                noAudioMessage
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
                withAnimation(.linear(duration: 0.1)) {
                    sliderValue = audioPlayer.currentTime
                }
            }
        }
    }

    // MARK: - Audio Player Controls

    private var audioPlayerControls: some View {
        VStack(spacing: AppSpacing.medium) {
            // Slider Row
            HStack(spacing: AppSpacing.medium) {
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
                .tint(AppColor.color1)

                Button {
                    audioPlayer.toggleRepeat()
                } label: {
                    Image(systemName: audioPlayer.repeatMode == .off ? "repeat" : "repeat.1")
                        .font(AppFont.title3)
                        .foregroundStyle(audioPlayer.repeatMode == .off ? Color.secondary : Color.accentColor)
                        .padding(6)
                        .background(
                            audioPlayer.repeatMode == .off ? Color.clear : Color.accentColor.opacity(0.15)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            
            // Controls Row
            HStack {
                Text(audioPlayer.currentTime.formattedTime())
                    .font(AppFont.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 45, alignment: .leading)

                Spacer()

                HStack(alignment: .center, spacing: 24) {
                    Button {
                        audioPlayer.skipForward(by: -5.0)
                    } label: {
                        Image(systemName: "gobackward.5")
                    }

                    Button {
                        audioPlayer.togglePlayPause()
                    } label: {
                        Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.primary, AppColor.color1)
                    }

                    Button {
                        audioPlayer.skipForward(by: 5.0)
                    } label: {
                        Image(systemName: "goforward.5")
                    }
                }
                .buttonStyle(.plain)
                .font(.title2)
                .foregroundStyle(.primary)

                Spacer()

                Text("-\(audioPlayer.timeLeft.formattedTime())")
                    .font(AppFont.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 45, alignment: .trailing)
            }
        }
        .padding(AppSpacing.large)
        .adaptiveGlass()
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.extraLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.extraLarge)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppColor.color1.opacity(0.3), AppColor.color2.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 10)
        .shadow(color: AppColor.color1.opacity(0.05), radius: 5, x: 0, y: -2)
    }

    // MARK: - Download Button

    private var downloadButton: some View {
        Button {
            Task {
                await audioPlayer.downloadAndSetup(song: song)
            }
        } label: {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                Text("Download Audio")
            }
            .font(AppFont.headline)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppColor.color1)
        .background(Color.accentColor.opacity(0.1))
        .adaptiveGlass()
        .clipShape(Capsule())
    }

    // MARK: - Downloading Indicator

    private var downloadingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Downloading...")
                .font(AppFont.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, 12)
        .adaptiveGlass()
        .clipShape(Capsule())
    }

    // MARK: - No Audio Message

    private var noAudioMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.slash")
            Text("No audio available")
        }
        .font(AppFont.subheadline)
        .foregroundStyle(.secondary)
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, 10)
        .adaptiveGlass()
        .clipShape(Capsule())
    }

    // MARK: - Checking Indicator

    private var checkingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
        }
        .padding(12)
        .adaptiveGlass()
        .clipShape(Circle())
    }
}
