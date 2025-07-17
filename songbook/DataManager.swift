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
    static let bundledCSVVersion: Int = 3
    
    // urls
    static let csvVersionURL: String = ""
    static let csvDownloadURL: String = ""
    
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
    }
    
    func refreshAndUpdate() async {
        // get csv version
        let version = UserDefaults.standard.integer(forKey: "storedCSVVersion")
        let onlineVersion = await getCSVVersion() ?? 0
        
        let latestVersion = max(onlineVersion, DataManager.bundledCSVVersion)
        
        if latestVersion <= version {
            print("No need to update csv")
            print("latestVersion: \(latestVersion), version: \(version)")
            return
        }

        print("need to update data")
        
        if onlineVersion > version {
            print("Need to download csv")
            await downloadCSV()
        }
        
        do {
            try await performDatabaseUpdate()
            // set version to latest version
            UserDefaults.standard.set(latestVersion, forKey: "storedCSVVersion")
            print("Database update complete. Version: \(latestVersion)")
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
        // request from csvVersionURL
        // parse response
        // return version
        print("csv version from url not implemented")

        // delay for 10 seconds before returning version
        try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
        print("returning version 11")
        return 11
    }

    private func downloadCSV() async {
        // download csv from csvDownloadURL
        // save to songs.csv
        print("download csv not implemented")
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
        
        // load csv
        guard let csvPath = Bundle.main.path(forResource: "songs", ofType: "csv"),
              let csvContent = try? String(contentsOfFile: csvPath, encoding: .utf8) else {
            print("Error loading CSV file 'songs.csv'")
            return
        }
        
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
            song.title = cols[0]
            song.artist = cols[1]
            song.first_line = cols[2]
            song.filename = cols[3]
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
