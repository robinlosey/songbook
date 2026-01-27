//
//  StorageViewModel.swift
//  songbook
//
//  Manages downloaded audio files for the Storage settings view.
//

import Foundation
import CoreData

@MainActor
class StorageViewModel: ObservableObject {
    struct DownloadedAudio: Identifiable {
        let id: String  // filename without extension
        let title: String
        let fileSize: Int64
        let url: URL

        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }
    }

    @Published var downloadedFiles: [DownloadedAudio] = []
    @Published var totalSize: Int64 = 0
    @Published var isLoading = false

    private let fileManager = FileManager.default
    private let audioDirectory: URL

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        audioDirectory = appSupport.appendingPathComponent("audio")
        loadDownloadedAudio()
    }

    func loadDownloadedAudio() {
        isLoading = true

        guard fileManager.fileExists(atPath: audioDirectory.path) else {
            downloadedFiles = []
            totalSize = 0
            isLoading = false
            return
        }

        do {
            let files = try fileManager.contentsOfDirectory(
                at: audioDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .nameKey],
                options: [.skipsHiddenFiles]
            )

            var items: [DownloadedAudio] = []
            var total: Int64 = 0

            // get song titles from Core Data for nicer display
            let songTitles = fetchSongTitles()

            for fileURL in files where fileURL.pathExtension == "mp3" {
                let filename = fileURL.deletingPathExtension().lastPathComponent
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                let size = Int64(resourceValues.fileSize ?? 0)

                // use song title if available, otherwise filename
                let title = songTitles[filename] ?? filename

                items.append(DownloadedAudio(
                    id: filename,
                    title: title,
                    fileSize: size,
                    url: fileURL
                ))

                total += size
            }

            // sort by title
            downloadedFiles = items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            totalSize = total

        } catch {
            downloadedFiles = []
            totalSize = 0
        }

        isLoading = false
    }

    /// fetch song titles keyed by filename for display
    private func fetchSongTitles() -> [String: String] {
        let context = DataManager.shared.container.viewContext
        let request: NSFetchRequest<Song> = Song.fetchRequest()

        do {
            let songs = try context.fetch(request)
            var titles: [String: String] = [:]
            for song in songs {
                if let filename = song.filename, let title = song.title {
                    titles[filename] = title
                }
            }
            return titles
        } catch {
            return [:]
        }
    }

    func deleteFile(at offsets: IndexSet) {
        for index in offsets {
            let file = downloadedFiles[index]
            do {
                try fileManager.removeItem(at: file.url)
                totalSize -= file.fileSize
            } catch {
                // silently fail, reload will sync state
            }
        }
        downloadedFiles.remove(atOffsets: offsets)
    }

    func deleteFile(_ file: DownloadedAudio) {
        do {
            try fileManager.removeItem(at: file.url)
            totalSize -= file.fileSize
            downloadedFiles.removeAll { $0.id == file.id }
        } catch {
            // silently fail
        }
    }

    func deleteAllAudio() {
        for file in downloadedFiles {
            try? fileManager.removeItem(at: file.url)
        }
        downloadedFiles = []
        totalSize = 0
    }
}
