//
//  DataManager.swift
//  songbook
//
//  Created by acemavrick on 6/4/25.
//

import CoreData
import Foundation

struct DataManager {
    static let shared = DataManager()

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
    static let bundledCSVVersion: Int = 20250719002
    
    // urls
    var csvVersionURL: String = ""
    var csvDownloadURL: String = ""
    
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
        csvVersionURL = config?["csvVersionURL"] as? String ?? ""
        csvDownloadURL = config?["csvDownloadURL"] as? String ?? ""
    }
    
    func refreshAndUpdate() async {
        let bundledVersion = DataManager.bundledCSVVersion
        let storedVersion = UserDefaults.standard.integer(forKey: "storedCSVVersion")
        let onlineVersion = await getCSVVersion() ?? 0
        
        print("bundledVersion: \(bundledVersion), onlineVersion: \(onlineVersion), storedVersion: \(storedVersion)")
        
        var finalVersion = max(onlineVersion, bundledVersion)
        
        var needsDownload = false
        
        if finalVersion <= storedVersion {
            print("No update needed")
            return
        }

        
        var targetIsOnline = finalVersion == onlineVersion

        print("update necessary, \(storedVersion) -> \(finalVersion), from \(targetIsOnline ? "online" : "bundled")")
        
        if targetIsOnline {
            let success = await downloadCSV()
            if !success {
                print("Download failed - falling back to bundled version")
                finalVersion = bundledVersion
                if finalVersion <= storedVersion {
                    print("Fallback is unnecessary; bundled version is older than stored version")
                    return
                }
            }
        }
        
        // check once again, just in case
        if finalVersion <= storedVersion {
            print("No update needed")
            return
        }
        
        do {
            try await performDatabaseUpdate()
            // set version to latest version
            UserDefaults.standard.set(finalVersion, forKey: "storedCSVVersion")
            print("Database update complete. Version: \(finalVersion)")
        } catch {
            print("Failed to update database: \(error.localizedDescription)")
        }
    }

    private func performDatabaseUpdate() async throws {
        try await container.performBackgroundTask { context in
            // Flush database
            let entityNames = self.container.managedObjectModel.entities.compactMap { $0.name }
            for entityName in entityNames {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                try context.execute(deleteRequest)
            }

            print("flushed database")

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
        print("clean up unused resources not implemented")
    }
    
    private func getCSVVersion() async -> Int? {
        guard let url = URL(string: csvVersionURL) else {
            print("Invalid url: \(csvVersionURL)")
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let versionString = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let versionString = versionString,
                  let version = Int(versionString) else {
                print("Could not parse version from response")
                return nil
            }
            
            print("Online CSV version: \(version)")
            return version
        } catch {
            print("Failed to fetch CSV version: \(error.localizedDescription)")
            return nil
        }
    }

    private func downloadCSV() async -> Bool {
        // download csv from csvDownloadURL
        // save to songs.csv
        guard let url = URL(string: csvDownloadURL) else {
            print("Invalid url: \(csvDownloadURL)")
            return false
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let csvPath = appSupportPath.appendingPathComponent("songs.csv")

            try FileManager.default.createDirectory(at: appSupportPath, withIntermediateDirectories: true)

            try data.write(to: csvPath)
            print("Downloaded CSV to \(csvPath)")
            return true
        } catch {
            print("Failed to download CSV: \(error.localizedDescription)")
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
            print("Could not fetch Category: \(error.localizedDescription). Creating a new one.")
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

    private func downloadSongResources(for song: String) {
        print("download song resources not implemented")
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
            print("No CSV content found")
            return
        }

        print("Loaded CSV from \(source)")
        
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
                print("Skipping malformed line (expected 6 columns, got \(cols.count)): \(line)")
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
                print("Skipping song with missing required fields: \(line)")
                continue
            }

            print("Loaded song: \(title) by \(artist)")

            // check for pdf and mp3
            // todo fix, doesn't work
            let pdfPath = Bundle.main.path(forResource: filename, ofType: "pdf")
            let mp3Path = Bundle.main.path(forResource: filename, ofType: "mp3")
            if pdfPath == nil || mp3Path == nil {
                print("Song has no pdf or mp3: \(title), with filename: \(filename)")
                downloadSongResources(for: filename)
            }
        }
        
        // save context is handled in `performDatabaseUpdate`
    }
}
