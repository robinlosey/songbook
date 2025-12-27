//
//  DataManager.swift
//  songbook
//
//  A/B database pattern for safe updates. Manages two CoreData stores,
//  switching between them after successful builds.
//

import CoreData
import Foundation
import os.log

final class DataManager: @unchecked Sendable {
    static let shared = DataManager()
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DataManager")
    static let bundledCSVVersion: Int = 20250719001
    
    // A/B store URLs
    private let storeA: URL
    private let storeB: URL
    
    // current active container
    private(set) var container: NSPersistentContainer
    
    // config URLs from plist
    let csvVersionURL: String
    let csvDownloadURL: String
    let pdfDownloadURL: String
    let mp3DownloadURL: String
    
    // which store is currently active ("A" or "B")
    var currentStore: String {
        get { UserDefaults.standard.string(forKey: SyncKeys.currentDB) ?? "A" }
        set { UserDefaults.standard.set(newValue, forKey: SyncKeys.currentDB) }
    }
    
    private var inactiveStore: String {
        currentStore == "A" ? "B" : "A"
    }
    
    private var currentStoreURL: URL {
        currentStore == "A" ? storeA : storeB
    }
    
    private var inactiveStoreURL: URL {
        currentStore == "A" ? storeB : storeA
    }
    
    init(storeDirectory: URL? = nil) {
        // set up store paths
        let directory = storeDirectory ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        storeA = directory.appendingPathComponent("songbook_A.sqlite")
        storeB = directory.appendingPathComponent("songbook_B.sqlite")
        
        // ensure directory exists
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // load config
        guard let path = Bundle.main.path(forResource: "config", ofType: "plist") else {
            fatalError("Could not find config.plist")
        }
        let config = NSDictionary(contentsOfFile: path)
        csvVersionURL = config?["csvVersionURL"] as? String ?? ""
        csvDownloadURL = config?["csvDownloadURL"] as? String ?? ""
        pdfDownloadURL = config?["basePDFURL"] as? String ?? ""
        mp3DownloadURL = config?["baseAudioURL"] as? String ?? ""
        
        // load current store
        let currentStoreKey = UserDefaults.standard.string(forKey: SyncKeys.currentDB) ?? "A"
        container = Self.createContainer(at: currentStoreKey == "A" ? storeA : storeB)
        Self.logger.info("DataManager initialized with store \(self.currentStore)")
    }
    
    private init(inMemory: Bool) {
        // in-memory store for testing/previews
        storeA = URL(fileURLWithPath: "/dev/null")
        storeB = URL(fileURLWithPath: "/dev/null")
        csvVersionURL = ""
        csvDownloadURL = ""
        pdfDownloadURL = ""
        mp3DownloadURL = ""
        
        container = NSPersistentContainer(name: "songbook")
        container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Factory Methods
    
    static func inMemory() -> DataManager {
        DataManager(inMemory: true)
    }
    
    @MainActor
    static var preview: DataManager = {
        let result = DataManager(inMemory: true)
        let viewContext = result.container.viewContext
        
        let evenCategory = Category(context: viewContext)
        evenCategory.name = "Even"
        
        let oddCategory = Category(context: viewContext)
        oddCategory.name = "Odd"
        
        for i in 0..<10 {
            let song = Song(context: viewContext)
            song.title = "\(i+1) Sample Song"
            song.artist = "\(10-i) Sample Artist"
            song.first_line = "Sample first line \(i)"
            song.filename = "sample_song_\(i+1)"
            song.isFavorite = i % 3 == 0
            song.addToCategories(i % 2 == 0 ? evenCategory : oddCategory)
        }
        
        try? viewContext.save()
        return result
    }()
    
    // MARK: - Container Management
    
    private static func createContainer(at url: URL) -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "songbook")
        container.persistentStoreDescriptions.first!.url = url
        
        container.loadPersistentStores { _, error in
            if let error = error {
                Self.logger.error("Failed to load store at \(url): \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }
    
    /// creates a container for the inactive store (for building new DB)
    func createInactiveContainer() -> NSPersistentContainer {
        Self.logger.info("Creating inactive container at store \(self.inactiveStore)")
        return Self.createContainer(at: inactiveStoreURL)
    }
    
    /// flips to the inactive store after successful build (main thread for thread safety)
    @MainActor
    func switchToInactiveStore() {
        let newStore = inactiveStore
        Self.logger.info("Switching from store \(self.currentStore) to \(newStore)")
        
        // update the toggle
        currentStore = newStore
        
        // reload container with new store
        container = Self.createContainer(at: currentStoreURL)
    }
    
    /// flushes all entities from a container
    func flushDatabase(_ targetContainer: NSPersistentContainer) throws {
        let context = targetContainer.viewContext
        let entityNames = targetContainer.managedObjectModel.entities.compactMap { $0.name }
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)
        }
        try context.save()
        Self.logger.info("Flushed database")
    }
    
    // MARK: - Favorites
    
    /// fetches filenames of all favorited songs from current store
    func fetchFavoriteFilenames() -> Set<String> {
        let context = container.viewContext
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")
        
        do {
            let favorites = try context.fetch(request)
            let filenames = Set(favorites.compactMap { $0.filename })
            Self.logger.info("Fetched \(filenames.count) favorites")
            return filenames
        } catch {
            Self.logger.error("Failed to fetch favorites: \(error)")
            return []
        }
    }
    
    // MARK: - Population
    
    /// populates a container from DTOs, applying favorites by filename match
    func populate(_ targetContainer: NSPersistentContainer,
                  with songs: [SongDTO],
                  favorites: Set<String>) throws {
        let context = targetContainer.viewContext
        
        // category cache for efficiency
        var categoryCache: [String: Category] = [:]
        
        for dto in songs {
            let song = Song(context: context)
            song.title = dto.title
            song.artist = dto.artist
            song.first_line = dto.firstLine
            song.filename = dto.filename
            song.reference = dto.reference
            song.isFavorite = favorites.contains(dto.filename)
            
            // handle categories
            for categoryName in dto.categories {
                let category: Category
                if let cached = categoryCache[categoryName] {
                    category = cached
                } else {
                    category = findOrCreateCategory(withName: categoryName, in: context)
                    categoryCache[categoryName] = category
                }
                song.addToCategories(category)
            }
        }
        
        try context.save()
        Self.logger.info("Populated database with \(songs.count) songs")
    }
    
    private func findOrCreateCategory(withName name: String, in context: NSManagedObjectContext) -> Category {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1
        
        if let existing = try? context.fetch(request).first {
            return existing
        }
        
        let category = Category(context: context)
        category.name = name
        return category
    }
    
    // MARK: - Resource Paths
    
    static func getSongPDF(for filename: String) -> URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pdfPath = appSupport.appendingPathComponent("pdfs/\(filename).pdf")
        
        if FileManager.default.fileExists(atPath: pdfPath.path) {
            return pdfPath
        }
        if let bundlePath = Bundle.main.path(forResource: filename, ofType: "pdf") {
            return URL(fileURLWithPath: bundlePath)
        }
        return nil
    }
    
    static func getSongMP3(for filename: String) -> URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let mp3Path = appSupport.appendingPathComponent("audio/\(filename).mp3")
        
        if FileManager.default.fileExists(atPath: mp3Path.path) {
            return mp3Path
        }
        if let bundlePath = Bundle.main.path(forResource: filename, ofType: "mp3") {
            return URL(fileURLWithPath: bundlePath)
        }
        return nil
    }
    
    // MARK: - Queries
    
    func fetchAllSongs() -> [Song] {
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        return (try? container.viewContext.fetch(request)) ?? []
    }
    
    func fetchAllCategories() -> [Category] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        return (try? container.viewContext.fetch(request)) ?? []
    }
}

