//
//  AudioViewModel.swift
//  songbook
//
//  Created by acemavrick on 6/11/25.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerViewModel: ObservableObject {

    enum PlaybackState {
        case stopped
        case setup(song: Song)
        case playing(song: Song)
        case paused(song: Song)
        case failed(error: AudioPlayerError)
    }

    enum AudioPlayerError: Error, LocalizedError {
        case fileNotFound(String)
        case emptyFileName
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound(let filename):
                return "Audio file '\(filename).mp3' not found in application bundle."
            case .emptyFileName:
                return "Song has an empty filename."
            }
        }
    }

    @Published private(set) var playbackState: PlaybackState = .stopped
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    var timeLeft: TimeInterval {
        max(0, duration - currentTime)
    }

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()

    var currentSong: Song? {
        switch playbackState {
        case .playing(let song), .paused(let song):
            return song
        default:
            return nil
        }
    }

    var isPlaying: Bool {
        if case .playing = playbackState {
            return true
        }
        return false
    }

    init() {
        configureAudioSession()
    }
    
    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }
    
    // set the song up, so starting playback is quick
    func setup(song: Song) {
        stop()

        guard let filename = song.filename, !filename.isEmpty else {
            playbackState = .failed(error: .emptyFileName)
            return
        }

        guard let url = Bundle.main.url(forResource: filename, withExtension: "mp3") else {
            playbackState = .failed(error: .fileNotFound(filename))
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        playbackState = .setup(song: song)

        setupObservers(for: playerItem)
    }
    
    func play() {
        guard player != nil else { return }
        
        switch playbackState {
        case .setup(let song), .paused(let song):
            player?.play()
            playbackState = .playing(song: song)
        default:
            break
        }
    }
    
    func pause() {
        guard player != nil else { return }
        
        switch playbackState {
        case .playing(let song):
            player?.pause()
            playbackState = .paused(song: song)
        default:
            break
        }
    }

    
    func togglePlayPause() {
        guard player != nil else { return }

        switch playbackState {
        case .playing:
            pause()
        case .paused, .setup:
            play()
        default:
            break
        }
    }

    func stop() {
        player?.pause()
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        player = nil
        playbackState = .stopped
        currentTime = 0
        duration = 0
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }

    private func setupObservers(for playerItem: AVPlayerItem) {
        // Observe current time
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.016, preferredTimescale: 1000), queue: .main) { [weak self] time in
            Task { @MainActor in
                let currentTime = time.seconds
                self?.currentTime = currentTime
            }
        }

        // Observe duration from the player item
        playerItem.publisher(for: \.duration)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                guard duration.isNumeric else { return }
                self?.duration = duration.seconds
            }
            .store(in: &cancellables)

        // Observe when the player item has finished playing
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.player?.seek(to: .zero)
                Task { @MainActor in
                    self?.currentTime = 0
                }
            }
            .store(in: &cancellables)
        
        // observe the player's rate to automatically update the playback state
        // this handles interruptions (like phone calls) and remote commands.
        player?.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                guard let self = self else { return }
                switch self.playbackState {
                case .playing(let song) where rate == 0:
                    self.playbackState = .paused(song: song)
                case .paused(let song) where rate > 0:
                    self.playbackState = .playing(song: song)
                case .setup(let song) where rate > 0:
                    self.playbackState = .playing(song: song)
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}
