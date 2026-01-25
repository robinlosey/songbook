//
//  DataManagerTests.swift
//  tests
//
//  tests for datamanager with in-memory store
//

import Testing
import CoreData
@testable import songbook

@Suite("DataManager Tests")
@MainActor
struct DataManagerTests {

    let dataManager: DataManager

    init() {
        dataManager = DataManager.inMemory()
    }

    @Test("populate creates songs in db")
    func populateWithSongs() async throws {
        let songs = [
            SongDTO(title: "Song One", artist: "Artist A", firstLine: "First line", filename: "song_one", reference: "Ref1", categories: ["Cat1"]),
            SongDTO(title: "Song Two", artist: "Artist B", firstLine: "First line", filename: "song_two", reference: "Ref2", categories: ["Cat1", "Cat2"])
        ]

        try await dataManager.populate(dataManager.container, with: songs, favorites: [])

        let fetched = dataManager.fetchAllSongs()
        #expect(fetched.count == 2)
    }

    @Test("populate preserves favorites by filename")
    func populatePreservesFavorites() async throws {
        let songs = [
            SongDTO(title: "Song One", artist: "Artist A", firstLine: "First", filename: "song_one", reference: "", categories: []),
            SongDTO(title: "Song Two", artist: "Artist B", firstLine: "First", filename: "song_two", reference: "", categories: [])
        ]

        try await dataManager.populate(dataManager.container, with: songs, favorites: ["song_one"])

        let fetched = dataManager.fetchAllSongs()
        let favorited = fetched.filter { $0.isFavorite }

        #expect(favorited.count == 1)
        #expect(favorited.first?.filename == "song_one")
    }

    @Test("fetch favorite filenames returns set")
    func fetchFavoriteFilenames() async throws {
        let songs = [
            SongDTO(title: "Song One", artist: "Artist A", firstLine: "First", filename: "song_one", reference: "", categories: []),
            SongDTO(title: "Song Two", artist: "Artist B", firstLine: "First", filename: "song_two", reference: "", categories: []),
            SongDTO(title: "Song Three", artist: "Artist C", firstLine: "First", filename: "song_three", reference: "", categories: [])
        ]

        try await dataManager.populate(dataManager.container, with: songs, favorites: ["song_one", "song_three"])

        let favorites = dataManager.fetchFavoriteFilenames()

        #expect(favorites.count == 2)
        #expect(favorites.contains("song_one"))
        #expect(favorites.contains("song_three"))
        #expect(!favorites.contains("song_two"))
    }

    @Test("categories are created from song data")
    func categoriesCreated() async throws {
        let songs = [
            SongDTO(title: "Song", artist: "Artist", firstLine: "First", filename: "song", reference: "", categories: ["Category A", "Category B"])
        ]

        try await dataManager.populate(dataManager.container, with: songs, favorites: [])

        let categories = dataManager.fetchAllCategories()
        let categoryNames = Set(categories.compactMap { $0.name })

        #expect(categoryNames.contains("Category A"))
        #expect(categoryNames.contains("Category B"))
    }

    @Test("categories are reused not duplicated")
    func categoriesReused() async throws {
        let songs = [
            SongDTO(title: "Song One", artist: "Artist", firstLine: "First", filename: "song_one", reference: "", categories: ["SharedCat"]),
            SongDTO(title: "Song Two", artist: "Artist", firstLine: "First", filename: "song_two", reference: "", categories: ["SharedCat"])
        ]

        try await dataManager.populate(dataManager.container, with: songs, favorites: [])

        let categories = dataManager.fetchAllCategories()
        let sharedCategories = categories.filter { $0.name == "SharedCat" }

        #expect(sharedCategories.count == 1)
    }

    @Test("flush database removes all entities")
    func flushDatabase() async throws {
        let songs = [
            SongDTO(title: "Song", artist: "Artist", firstLine: "First", filename: "song", reference: "", categories: ["Cat"])
        ]

        try await dataManager.populate(dataManager.container, with: songs, favorites: [])
        #expect(dataManager.fetchAllSongs().count == 1)

        try dataManager.flushDatabase(dataManager.container)

        #expect(dataManager.fetchAllSongs().count == 0)
        #expect(dataManager.fetchAllCategories().count == 0)
    }

    @Test("reference field is stored correctly")
    func referenceFieldStored() async throws {
        let songs = [
            SongDTO(title: "Song", artist: "Artist", firstLine: "First", filename: "song", reference: "My Reference", categories: [])
        ]

        try await dataManager.populate(dataManager.container, with: songs, favorites: [])

        let fetched = dataManager.fetchAllSongs().first
        #expect(fetched?.reference == "My Reference")
    }

    @Test("batch pdf availability returns empty for nonexistent files")
    func batchPDFAvailability() {
        let filenames = ["test1", "test2", "test3"]
        let available = DataManager.getBatchPDFAvailability(for: filenames)

        #expect(available.isEmpty)
    }

    @Test("batch mp3 availability returns empty for nonexistent files")
    func batchMP3Availability() {
        let filenames = ["test1", "test2", "test3"]
        let available = DataManager.getBatchMP3Availability(for: filenames)

        #expect(available.isEmpty)
    }
}
