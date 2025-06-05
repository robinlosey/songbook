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
        // Preview data can be more specific if needed, e.g., loading a few sample songs
        for i in 0..<5 {
            let newSong = Song(context: viewContext)
            newSong.title = "Sample Song \(i + 1)"
            newSong.artist = "Sample Artist \(i + 1)"
            newSong.first_line = "This is the first line of sample song \(i + 1)."
            newSong.filename = "sample_song_\(i+1)"
            newSong.isFavorite = false
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

    private func parseCSV(line: String) -> [String] {
        var fields = [String]()
        var buffer = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0

        while i < chars.count {
            let char = chars[i]

            if char == "\"" { // Double quote character
                // Check for an escaped quote ("")
                if inQuotes && i + 1 < chars.count && chars[i+1] == "\"" {
                    buffer.append("\"") // Append one quote to the buffer
                    i += 1 // Advance past the second quote of the pair
                } else {
                    inQuotes.toggle() // Entering or exiting a quoted field
                                      // The quote itself is a delimiter, not part of the content
                }
            } else if char == "," && !inQuotes { // Comma delimiter outside of quotes
                fields.append(buffer)
                buffer = ""
            } else {
                buffer.append(char) // Append character to current field buffer
            }
            i += 1
        }
        fields.append(buffer) // Add the last field

        // Trim whitespace from all parsed fields
        return fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func loadSongsFromCSVIfNeeded() {
        let context = container.viewContext
        // check if songs already exist
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        do {
            let existingSongs = try context.fetch(request)
            if !existingSongs.isEmpty {
                print("Songs already loaded, skipping CSV import.")
                return
            }
        } catch {
            print("Error fetching existing songs: \(error.localizedDescription)")
            // if fetching fails, we might still want to try loading
        }
        
        // load csv
        guard let csvPath = Bundle.main.path(forResource: "songs", ofType: "csv"),
              let csvContent = try? String(contentsOfFile: csvPath, encoding: .utf8) else {
            print("Error loading CSV file. Make sure 'songs.csv' is added to the target.")
            return
        }
        
        // csv structure: title,artist,first line,filename,Reference,Indices
        // ignore reference, indices are colon-sep list of categories
        
        // parse csv
        let lines = csvContent.components(separatedBy: .newlines)
        for line in lines.dropFirst() { // skip header
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue // skip empty lines
            }
            let cols = parseCSV(line: line)
            guard cols.count >= 4 else { // Ensure at least title, artist, first_line, filename
                print("Skipping malformed line (expected at least 4 columns, got \(cols.count)): \(line)")
                continue
            }
            
            let song = Song(context: context)
            song.title = cols[0]
            song.artist = cols[1]
            song.first_line = cols[2]
            song.filename = cols[3]
            song.isFavorite = false // default to false

            // todo handle categories (column 5 if present, cols[4], and indices from cols[5])
            
            print("Loaded song: \(song.title ?? "Unknown") by \(song.artist ?? "Unknown")")
        }
        
        // save context
        do {
            try context.save()
            print("Successfully saved songs to Core Data.")
        } catch {
            print("Failed to save songs: \(error.localizedDescription)")
        }
    }
}
