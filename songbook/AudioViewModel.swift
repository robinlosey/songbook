//
//  AudioViewModel.swift
//  songbook
//
//  Created by acemavrick on 6/11/25.
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer
import os.log

@MainActor
class AudioPlayerViewModel: ObservableObject {

    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AudioPlayerViewModel")

    enum RepeatMode {
        case off
        case repeatOne
    }

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
        case noAudioAvailable
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound(let filename):
                return "Audio file '\(filename).mp3' not found."
            case .emptyFileName:
                return "Song has an empty filename."
            case .noAudioAvailable:
                return "No audio available for this song."
            }
        }
    }
    
    // tracks MP3 availability for current song
    enum AudioAvailability: Equatable {
        case available
        case downloadable
        case downloading
        case notFound
        case unknown
    }

    @Published private(set) var playbackState: PlaybackState = .stopped
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var repeatMode: RepeatMode = .off
    @Published private(set) var audioAvailability: AudioAvailability = .unknown
    
    var timeLeft: TimeInterval {
        max(0, duration - currentTime)
    }

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    private var artwork: MPMediaItemArtwork?
    private var isAudioSessionConfigured = false

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
        setupRemoteTransportControls()
        setupArtwork()
    }
    
    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }
    
    private func setupArtwork() {
        if let image = UIImage(named: "NowPlayingIcon") {
            artwork = MPMediaItemArtwork(boundsSize: image.size) { @Sendable size in
                let renderer = UIGraphicsImageRenderer(size: size)
                return renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
            }
        }
    }
    
    // sets up the song for playback, checking MP3 availability
    func setup(song: Song) {
        stop()
        audioAvailability = .unknown

        guard let filename = song.filename, !filename.isEmpty else {
            playbackState = .failed(error: .emptyFileName)
            audioAvailability = .notFound
            return
        }

        // check if MP3 is available locally
        if let url = DataManager.getSongMP3(for: filename) {
            audioAvailability = .available
            let playerItem = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: playerItem)
            playbackState = .setup(song: song)
            setupObservers(for: playerItem)
            return
        }
        
        // MP3 not local - check availability async
        AudioPlayerViewModel.logger.info("MP3 not local for \(song.title ?? "Unknown"), checking availability")
        playbackState = .stopped
        
        Task {
            let availability = await DownloadService.shared.checkMP3Availability(for: filename)
            await MainActor.run {
                switch availability {
                case .available(let url):
                    self.audioAvailability = .available
                    let playerItem = AVPlayerItem(url: url)
                    self.player = AVPlayer(playerItem: playerItem)
                    self.playbackState = .setup(song: song)
                    self.setupObservers(for: playerItem)
                case .downloadable:
                    self.audioAvailability = .downloadable
                case .notFound, .checking:
                    self.audioAvailability = .notFound
                }
            }
        }
    }
    
    // downloads and sets up MP3 for current song
    func downloadAndSetup(song: Song) async {
        guard let filename = song.filename, !filename.isEmpty else { return }
        
        await MainActor.run {
            audioAvailability = .downloading
        }
        
        let success = await DownloadService.shared.downloadMP3(for: filename)
        
        if success {
            await MainActor.run {
                setup(song: song)
            }
        } else {
            await MainActor.run {
                audioAvailability = .notFound
            }
        }
    }
    
    func play() {
        guard player != nil else { 
            AudioPlayerViewModel.logger.error("Player is nil")
            return
        }
        
        if !isAudioSessionConfigured {
            configureAudioSession()
            isAudioSessionConfigured = true
        }
        
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
        guard player != nil else {
            AudioPlayerViewModel.logger.error("Player is nil")
            return
        }

        switch playbackState {
        case .playing:
            pause()
        case .paused, .setup:
            play()
        default:
            break
        }
    }

    func toggleRepeat() {
        if repeatMode == .off {
            repeatMode = .repeatOne
        } else {
            repeatMode = .off
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
        audioAvailability = .unknown
        currentTime = 0
        duration = 0
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        let clampedTime = max(0, min(time, duration))
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            if finished {
                Task {
                    await self?.updateNowPlayingInfo()
                }
            }
        }
    }
    
    func skipForward(by seconds: Double) {
        seek(to: currentTime + seconds)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
        } catch {
            AudioPlayerViewModel.logger.error("Failed to set up audio session: \(error.localizedDescription)")
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
                self?.updateNowPlayingInfo()
            }
            .store(in: &cancellables)

        // Observe when the player item has finished playing
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.player?.seek(to: .zero)
                if self.repeatMode == .repeatOne {
                    self.player?.play()
                } else {
                    Task { @MainActor in
                        self.currentTime = 0
                    }
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
                self.updateNowPlayingInfo()
            }
            .store(in: &cancellables)
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
    }

    private func updateNowPlayingInfo() {
        guard let song = currentSong, player != nil else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title ?? "Unknown Title"
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist ?? "Unknown Artist"
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0.0
        
        if let art = artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = art
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
