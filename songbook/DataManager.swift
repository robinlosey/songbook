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
            guard cols.count >= 6 else { // Ensure at least title, artist, first_line, filename, ref, and indices
                print("Skipping malformed line (expected at least 6 columns, got \(cols.count)): \(line)")
                continue
            }
            
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
