//
//  DataManager.swift
//  songbook
//
//  a/b database pattern for safe updates - manages two coredata stores,
//  switching between them after successful builds
//

import CoreData
import Foundation
import os.log

// @unchecked sendable: container is mutable but only accessed/mutated on main thread
// switchToInactiveStore is @MainActor and all viewmodel access is on main thread
final class DataManager: @unchecked Sendable {
    static let shared = DataManager()
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DataManager")
    static let bundledCSVVersion: Int = 20250719001

    private let storeA: URL
    private let storeB: URL

    private(set) var container: NSPersistentContainer

    let queryCache: QueryCache

    let csvVersionURL: String
    let csvDownloadURL: String
    let pdfDownloadURL: String
    let mp3DownloadURL: String

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
        let directory = storeDirectory ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        storeA = directory.appendingPathComponent("songbook_A.sqlite")
        storeB = directory.appendingPathComponent("songbook_B.sqlite")

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let configPath = "config_test"
        guard let path = Bundle.main.path(forResource: configPath, ofType: "plist") else {
            fatalError("Could not find config at \(configPath).plist")
        }
        let config = NSDictionary(contentsOfFile: path)
        csvVersionURL = config?["csvVersionURL"] as? String ?? ""
        csvDownloadURL = config?["csvDownloadURL"] as? String ?? ""
        pdfDownloadURL = config?["basePDFURL"] as? String ?? ""
        mp3DownloadURL = config?["baseAudioURL"] as? String ?? ""

        let currentStoreKey = UserDefaults.standard.string(forKey: SyncKeys.currentDB) ?? "A"
        container = Self.createContainer(at: currentStoreKey == "A" ? storeA : storeB)
        
        // Initialize queryCache on main thread since it's @MainActor isolated
        queryCache = MainActor.assumeIsolated {
            QueryCache()
        }
        
        Self.logger.info("DataManager initialized with store \(self.currentStore)")
    }

    @MainActor
    private init(inMemory: Bool) {
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

        queryCache = QueryCache()
    }

    // MARK: - Factory Methods

    @MainActor
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

    func createInactiveContainer() -> NSPersistentContainer {
        Self.logger.info("Creating inactive container at store \(self.inactiveStore)")
        return Self.createContainer(at: inactiveStoreURL)
    }

    @MainActor
    func switchToInactiveStore() {
        let newStore = inactiveStore
        Self.logger.info("Switching from store \(self.currentStore) to \(newStore)")

        currentStore = newStore
        container = Self.createContainer(at: currentStoreURL)

        queryCache.invalidateAll()

        NotificationCenter.default.post(name: .databaseDidSwitch, object: nil)
    }

    /// runs sync but uses semaphore to block until bg context completes
    func ensureInitialDatabase() {
        guard fetchAllSongs().isEmpty else {
            Self.logger.debug("Database already populated, skipping initial build")
            return
        }

        Self.logger.info("Database empty - building from bundled CSV")

        guard let bundlePath = Bundle.main.path(forResource: "songs", ofType: "csv"),
              let content = try? String(contentsOfFile: bundlePath, encoding: .utf8) else {
            Self.logger.error("Failed to load bundled CSV")
            return
        }

        do {
            let songs = try CSVParser.parse(content)
            try populateSync(container, with: songs, favorites: [])
            UserDefaults.standard.set(Self.bundledCSVVersion, forKey: SyncKeys.storedCSVVersion)
            Self.logger.info("Initial database built with \(songs.count) songs")
        } catch {
            Self.logger.error("Failed to build initial database: \(error)")
        }
    }

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

    func populate(_ targetContainer: NSPersistentContainer,
                  with songs: [SongDTO],
                  favorites: Set<String>) async throws {
        let backgroundContext = targetContainer.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        try await backgroundContext.perform {
            var categoryCache: [String: Category] = [:]

            for dto in songs {
                let song = Song(context: backgroundContext)
                song.title = dto.title
                song.artist = dto.artist
                song.first_line = dto.firstLine
                song.filename = dto.filename
                song.reference = dto.reference
                song.isFavorite = favorites.contains(dto.filename)

                for categoryName in dto.categories {
                    let category: Category
                    if let cached = categoryCache[categoryName] {
                        category = cached
                    } else {
                        category = self.findOrCreateCategory(withName: categoryName, in: backgroundContext)
                        categoryCache[categoryName] = category
                    }
                    song.addToCategories(category)
                }
            }

            try backgroundContext.save()
            Self.logger.info("Populated database with \(songs.count) songs on background context")
        }
    }

    /// Synchronous version of populate for use in non-async contexts
    func populateSync(_ targetContainer: NSPersistentContainer,
                      with songs: [SongDTO],
                      favorites: Set<String>) throws {
        let backgroundContext = targetContainer.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        try backgroundContext.performAndWait {
            var categoryCache: [String: Category] = [:]

            for dto in songs {
                let song = Song(context: backgroundContext)
                song.title = dto.title
                song.artist = dto.artist
                song.first_line = dto.firstLine
                song.filename = dto.filename
                song.reference = dto.reference
                song.isFavorite = favorites.contains(dto.filename)

                for categoryName in dto.categories {
                    let category: Category
                    if let cached = categoryCache[categoryName] {
                        category = cached
                    } else {
                        category = self.findOrCreateCategory(withName: categoryName, in: backgroundContext)
                        categoryCache[categoryName] = category
                    }
                    song.addToCategories(category)
                }
            }

            try backgroundContext.save()
            Self.logger.info("Populated database with \(songs.count) songs on background context (sync)")
        }
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

    // MARK: - Batch Resource Availability

    /// enumerates dirs once instead of N file checks - 10-100x faster
    static func getBatchPDFAvailability(for filenames: [String]) -> Set<String> {
        var availableSet = Set<String>()

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pdfDir = appSupport.appendingPathComponent("pdfs")

        if let contents = try? FileManager.default.contentsOfDirectory(
            at: pdfDir,
            includingPropertiesForKeys: nil
        ) {
            for url in contents where url.pathExtension == "pdf" {
                availableSet.insert(url.deletingPathExtension().lastPathComponent)
            }
        }

        if let bundledPDFs = Bundle.main.urls(forResourcesWithExtension: "pdf", subdirectory: nil) {
            for url in bundledPDFs {
                availableSet.insert(url.deletingPathExtension().lastPathComponent)
            }
        }

        let requestedSet = Set(filenames)
        let result = availableSet.intersection(requestedSet)

        Self.logger.debug("Batch PDF check: \(result.count)/\(filenames.count) available")
        return result
    }

    static func getBatchMP3Availability(for filenames: [String]) -> Set<String> {
        var availableSet = Set<String>()

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let mp3Dir = appSupport.appendingPathComponent("audio")

        if let contents = try? FileManager.default.contentsOfDirectory(
            at: mp3Dir,
            includingPropertiesForKeys: nil
        ) {
            for url in contents where url.pathExtension == "mp3" {
                availableSet.insert(url.deletingPathExtension().lastPathComponent)
            }
        }

        if let bundledMP3s = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: nil) {
            for url in bundledMP3s {
                availableSet.insert(url.deletingPathExtension().lastPathComponent)
            }
        }

        let requestedSet = Set(filenames)
        let result = availableSet.intersection(requestedSet)

        Self.logger.debug("Batch MP3 check: \(result.count)/\(filenames.count) available")
        return result
    }

    // MARK: - MP3 Availability

    enum MP3Availability: Equatable, Sendable {
        case available(URL)
        case downloadable
        case notFound
        case checking
    }

    static func getMP3Availability(for filename: String) -> MP3Availability {
        if let url = getSongMP3(for: filename) {
            return .available(url)
        }
        return .checking
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
