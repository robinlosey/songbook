//
//  DataManager.swift
//  songbook
//
//  Created by acemavrick on 6/4/25.
//

import CoreData
import Foundation
import os.log

struct DataManager {
    static let shared = DataManager()
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DataManager")

    @MainActor
    static var preview: DataManager = {
        let result = DataManager(inMemory: true)
        let viewContext = result.container.viewContext
        
        // create sample categories (odd and even)
        let evenCategory = Category(context: viewContext)
        evenCategory.name = "Even"
        
        let oddCategory = Category(context: viewContext)
        oddCategory.name = "Odd"
        
        // make sample songs
        for i in 0..<10 {
            let newSong = Song(context: viewContext)
            newSong.title = "\(i+1) Sample Song"
            newSong.artist = "\(10-i) Sample Artist"
            newSong.first_line = "line \(pow(-1, i)). This is the first line of sample song."
            newSong.filename = "sample_song_\(i+1)"
            newSong.isFavorite = false
            if i % 2 == 0 {
                newSong.addToCategories(evenCategory)
            } else {
                newSong.addToCategories(oddCategory)
            }
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    static let bundledCSVVersion: Int = 20250719001
    
    // urls
    let csvVersionURL: String
    let csvDownloadURL: String
    let pdfDownloadURL: String
    let mp3DownloadURL: String
    
    private let noCacheSession: URLSession = {
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.urlCache = nil
            return URLSession(configuration: config)
        }()

    enum UpdateStatus {
        case notStarted
        case updating
        case done
    }

    nonisolated(unsafe) static var updateStatus: DataManager.UpdateStatus = .notStarted

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "songbook")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true

        guard let path = Bundle.main.path(forResource: "config", ofType: "plist") else {
            fatalError("Could not find config.plist")
        }

        let config = NSDictionary(contentsOfFile: path)
        csvVersionURL = config?["csvVersionURL"] as? String ?? "couldn't find csvVersionURL"
        csvDownloadURL = config?["csvDownloadURL"] as? String ?? "couldn't find csvDownloadURL"
        pdfDownloadURL = config?["basePDFURL"] as? String ?? "couldn't find basePDFURL"
        mp3DownloadURL = config?["baseAudioURL"] as? String ?? "couldn't find baseAudioURL"
    }
    
    func refreshAndUpdate() async {
        DataManager.updateStatus = .updating

        if !UserDefaults.standard.bool(forKey: "verifyDB") {
            let out = verifyDB(context: container.viewContext)
            if out {
                UserDefaults.standard.set(true, forKey: "verifyDB")
            }
        }

        let bundledVersion = DataManager.bundledCSVVersion
        let storedVersion = UserDefaults.standard.integer(forKey: "storedCSVVersion")
        let onlineVersion = await getCSVVersion() ?? 0
        
        DataManager.logger.info("bundledVersion: \(bundledVersion), onlineVersion: \(onlineVersion), storedVersion: \(storedVersion)")
        
        var finalVersion = max(onlineVersion, bundledVersion)
        
        
        if finalVersion <= storedVersion {
            DataManager.logger.info("No update needed")
            DataManager.updateStatus = .done
            return
        }

        let targetIsOnline = finalVersion == onlineVersion

        DataManager.logger.info("update necessary, \(storedVersion) -> \(finalVersion), from \(targetIsOnline ? "online" : "bundled")")
        
        if targetIsOnline {
            let success = await downloadCSV()
            if !success {
                DataManager.logger.error("Download failed - falling back to bundled version")
                finalVersion = bundledVersion
                if finalVersion <= storedVersion {
                    DataManager.logger.warning("Fallback is unnecessary; bundled version is older than stored version")
                    DataManager.updateStatus = .done
                    return
                }
            }
        }
        
        // check once again, just in case
        if finalVersion <= storedVersion {
            DataManager.logger.info("No update needed")
            DataManager.updateStatus = .done
            return
        }
        
        do {
            try await performDatabaseUpdate()
            // set version to latest version
            UserDefaults.standard.set(finalVersion, forKey: "storedCSVVersion")
            DataManager.logger.info("Database update complete. Version: \(finalVersion)")
        } catch {
            DataManager.logger.error("Failed to update database: \(error.localizedDescription)")
        }
        DataManager.updateStatus = .done
    }

    private func performDatabaseUpdate() async throws {
        UserDefaults.standard.set(false, forKey: "verifyDB")
        try await container.performBackgroundTask { context in
            // Flush database
            let entityNames = self.container.managedObjectModel.entities.compactMap { $0.name }
            for entityName in entityNames {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                try context.execute(deleteRequest)
            }

            DataManager.logger.info("flushed database")

            // load songs from csv into the background context
            self.loadSongsFromCSV(context: context)

            // clean up any unused pdfs and mp3s
            self.cleanUpUnusedResources(context: context)
            
            // Save the background context to commit the entire transaction.
            try context.save()
        }
    }

    private func cleanUpUnusedResources(context: NSManagedObjectContext) {
        // delete any pdfs and mp3s that are not used by songs in the database
        // make a set of all pdfs and mp3s in the pdfs/ and audio/ directories
        // then, for each song, remove the pdf and mp3 from the set of paths we have
        // finally, delete any paths that are left in the set
        DataManager.logger.warning("clean up unused resources not implemented")
    }
    
    private func getCSVVersion() async -> Int? {
        guard let url = URL(string: csvVersionURL) else {
            DataManager.logger.error("Invalid url: \(self.csvVersionURL)")
            return nil
        }
        
        do {
            let request = URLRequest(url: url)
            let (data, _) = try await noCacheSession.data(for: request)
            let versionString = String(data: data, encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let versionString = versionString,
                  let version = Int(versionString) else {
                DataManager.logger.error("Could not parse version from response: \(versionString ?? "no response")")
                return nil
            }
            
            DataManager.logger.info("Online CSV version: \(version)")
            return version
        } catch {
            DataManager.logger.error("Failed to fetch CSV version: \(error.localizedDescription)")
            return nil
        }
    }

    private func downloadCSV() async -> Bool {
        // download csv from csvDownloadURL
        // save to songs.csv
        guard let url = URL(string: csvDownloadURL) else {
            DataManager.logger.error("Invalid url: \(self.csvDownloadURL)")
            return false
        }

        do {
            let request = URLRequest(url: url)
            
            let (data, _) = try await noCacheSession.data(for: request)
            
            let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let csvPath = appSupportPath.appendingPathComponent("songs.csv")

            try FileManager.default.createDirectory(at: appSupportPath, withIntermediateDirectories: true)

            try data.write(to: csvPath)
            DataManager.logger.info("Downloaded CSV to \(csvPath.absoluteString)")
            return true
        } catch {
            DataManager.logger.error("Failed to download CSV: \(error.localizedDescription)")
            return false
        }
    }

    private func findOrCreateCategory(withName name: String, in context: NSManagedObjectContext) -> Category {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1

        do {
            if let category = try context.fetch(request).first {
                return category
            }
        } catch {
            // Log the error but continue to create a new category, as that's the recovery path.
            DataManager.logger.error("Could not fetch Category: \(error.localizedDescription). Creating a new one.")
        }

        let newCategory = Category(context: context)
        newCategory.name = name
        return newCategory
    }

    private func parseCSV(line: String) -> [String] {
        var fields = [String]()
        var buffer = String()
        var inQuotes = false
        let chars = line
        var i = chars.startIndex
        
        while i < chars.endIndex {
            let char = chars[i]
            
            if char == "\"" {
                // Check for an escaped quote ("")
                let nextIndex = chars.index(after: i)
                if inQuotes && nextIndex < chars.endIndex && chars[nextIndex] == "\"" {
                    buffer.append("\"") // append escaped quote
                    i = chars.index(after: nextIndex) // skip both quotes
                    continue
                } else {
                    inQuotes.toggle() // toggle quote state
                }
            } else if char == "," && !inQuotes {
                fields.append(buffer)
                buffer = String()
            } else {
                buffer.append(char)
            }
            
            i = chars.index(after: i)
        }
        
        fields.append(buffer) // add final field
        
        // trim whitespace from all fields
        return fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func downloadSongPDF(for song: String) {
        guard let true_url = URL(string: pdfDownloadURL + "\(song).pdf") else {
            DataManager.logger.error("Invalid url: \(self.pdfDownloadURL)")
            return
        }

        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pdfPath = appSupportPath.appendingPathComponent("pdfs/\(song).pdf")

        Task {
            do {
                // create dir if it doesn't exist
                try FileManager.default.createDirectory(at: pdfPath.deletingLastPathComponent(),
                                                                   withIntermediateDirectories: true)
                
                let (data, _) = try await noCacheSession.data(from: true_url)
                DataManager.logger.debug("\(pdfPath.absoluteString)")
                DataManager.logger.debug("\(data)")
                try data.write(to: pdfPath)
                DataManager.logger.info("Downloaded PDF to \(pdfPath.absoluteString)")
            } catch {
                DataManager.logger.error("Failed to download PDF: \(error.localizedDescription)")
            }
        }
    }

    private func downloadSongMP3(for song: String) {
        guard let true_url = URL(string: mp3DownloadURL + "\(song).mp3") else {
            DataManager.logger.error("Invalid url: \(self.mp3DownloadURL)")
            return
        }
        
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let mp3Path = appSupportPath.appendingPathComponent("audio/\(song).mp3")
        
        Task {
            do {
                // create the dir if it doesn't exist
                try FileManager.default.createDirectory(at: mp3Path.deletingLastPathComponent(),
                                                                   withIntermediateDirectories: true)
                
                let (data, _) = try await noCacheSession.data(from: true_url)
                try data.write(to: mp3Path)
                DataManager.logger.debug("\(data)")
                DataManager.logger.info("Downloaded MP3 to \(mp3Path.absoluteString)")
            } catch {
                DataManager.logger.error("Failed to download mp3: \(error.localizedDescription)")
            }
        }
    }

    static func getSongPDF(for song: String) -> URL? {
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pdfPath = appSupportPath.appendingPathComponent("pdfs/\(song).pdf")
        if FileManager.default.fileExists(atPath: pdfPath.path) {
            return pdfPath
        }
        
        // check if in bundle
        if let bundlePath = Bundle.main.path(forResource: song, ofType: "pdf") {
            return URL(fileURLWithPath: bundlePath)
        }
        return nil
    }

    static func getSongMP3(for song: String) -> URL? {
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let mp3Path = appSupportPath.appendingPathComponent("audio/\(song).mp3")
        if FileManager.default.fileExists(atPath: mp3Path.path) {
            return mp3Path
        }

        // check if in bundle
        if let bundlePath = Bundle.main.path(forResource: song, ofType: "mp3") {
            return URL(fileURLWithPath: bundlePath)
        }
        return nil
    }

    private func loadSongsFromCSV(context: NSManagedObjectContext) {
        // try loading from app support first, then fall back to bundled resources
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appSupportCSVPath = appSupportPath.appendingPathComponent("songs.csv")
        
        var csvContent: String? = nil
        var source = ""
        
        if FileManager.default.fileExists(atPath: appSupportCSVPath.path) {
            source = "app support"
            csvContent = try? String(contentsOfFile: appSupportCSVPath.path, encoding: .utf8)
        }
        
        if csvContent == nil, let bundlePath = Bundle.main.path(forResource: "songs", ofType: "csv") {
            source = "bundled resources"
            csvContent = try? String(contentsOfFile: bundlePath, encoding: .utf8)
        }
        
        guard let csvContent = csvContent else {
            DataManager.logger.error("No CSV content found")
            return
        }

        DataManager.logger.info("Loaded CSV from \(source)")
        
        // csv structure: title,artist,first line,filename,Reference,Indices
        // ignore reference, indices are colon-sep list of categories
        
        // parse csv
        let lines = csvContent.components(separatedBy: .newlines)
        for line in lines.dropFirst() { // skip header

            // skip empty lines
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            // parse line
            let cols = parseCSV(line: line)
            guard cols.count == 6 else { // Ensure title, artist, first_line, filename, ref, and indices
                DataManager.logger.warning("Skipping malformed line (expected 6 columns, got \(cols.count)): \(line)")
                continue
            }

            // create song
            let song = Song(context: context)
            song.title = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
            song.artist = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
            song.first_line = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)
            song.filename = cols[3].trimmingCharacters(in: .whitespacesAndNewlines)
            song.isFavorite = false // default to false

            // handle categories from 'Indices' column (cols[5])
            if !cols[5].isEmpty {
                let categoryNames = cols[5].components(separatedBy: ":")
                for name in categoryNames {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty {
                        let category = findOrCreateCategory(withName: trimmedName, in: context)
                        song.addToCategories(category)
                    }
                }
            }
            
            // skip song if any required fields are missing
            guard let title = song.title, !title.isEmpty,
                  let artist = song.artist, !artist.isEmpty,
                  let filename = song.filename, !filename.isEmpty else {
                context.delete(song)
                DataManager.logger.warning("Skipping song with missing required fields: \(line)")
                continue
            }

            DataManager.logger.info("Loaded song: \(title) by \(artist)")

            // check for pdf and mp3
            let pdfPath = DataManager.getSongPDF(for: filename)
            if pdfPath == nil {
                DataManager.logger.info("Song has no pdf: \(title), with filename: \(filename)")
                downloadSongPDF(for: filename)
            }

            let mp3Path = DataManager.getSongMP3(for: filename)
            if mp3Path == nil {
                DataManager.logger.info("Song has no mp3: \(title), with filename: \(filename)")
                downloadSongMP3(for: filename)
            }
        }
    }
    
    private func verifyDB(context: NSManagedObjectContext) -> Bool {
        // verify that all songs have a pdf and mp3
        var broken = false
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        let songs = try? context.fetch(request)
        for song in songs ?? [] {
            let pdfPath = DataManager.getSongPDF(for: song.filename!)
            let mp3Path = DataManager.getSongMP3(for: song.filename!)
            if pdfPath == nil {
                DataManager.logger.error("Song has no pdf: \(song.title ?? "no title"), with filename: \(song.filename ?? "no filename")")
                downloadSongPDF(for: song.filename!)
                broken = true
            }
            if mp3Path == nil {
                DataManager.logger.error("Song has no mp3: \(song.title ?? "no title"), with filename: \(song.filename ?? "no filename")")
                downloadSongMP3(for: song.filename!)
                broken = true
            }
        }
        return !broken
    }
}
