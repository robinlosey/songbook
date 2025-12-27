//
//  DataManagerTests.swift
//  songbookTests
//
//  Unit tests for DataManager with in-memory store.
//

import XCTest
import CoreData
@testable import songbook

final class DataManagerTests: XCTestCase {
    
    var dataManager: DataManager!
    
    override func setUp() {
        super.setUp()
        dataManager = DataManager.inMemory()
    }
    
    override func tearDown() {
        dataManager = nil
        super.tearDown()
    }
    
    func testPopulateWithSongs() throws {
        let songs = [
            SongDTO(title: "Song One", artist: "Artist A", firstLine: "First line", filename: "song_one", reference: "Ref1", categories: ["Cat1"]),
            SongDTO(title: "Song Two", artist: "Artist B", firstLine: "First line", filename: "song_two", reference: "Ref2", categories: ["Cat1", "Cat2"])
        ]
        
        try dataManager.populate(dataManager.container, with: songs, favorites: [])
        
        let fetched = dataManager.fetchAllSongs()
        XCTAssertEqual(fetched.count, 2)
    }
    
    func testPopulatePreservesFavorites() throws {
        let songs = [
            SongDTO(title: "Song One", artist: "Artist A", firstLine: "First", filename: "song_one", reference: "", categories: []),
            SongDTO(title: "Song Two", artist: "Artist B", firstLine: "First", filename: "song_two", reference: "", categories: [])
        ]
        
        // favorite song_one
        try dataManager.populate(dataManager.container, with: songs, favorites: ["song_one"])
        
        let fetched = dataManager.fetchAllSongs()
        let favorited = fetched.filter { $0.isFavorite }
        
        XCTAssertEqual(favorited.count, 1)
        XCTAssertEqual(favorited.first?.filename, "song_one")
    }
    
    func testFetchFavoriteFilenames() throws {
        let songs = [
            SongDTO(title: "Song One", artist: "Artist A", firstLine: "First", filename: "song_one", reference: "", categories: []),
            SongDTO(title: "Song Two", artist: "Artist B", firstLine: "First", filename: "song_two", reference: "", categories: []),
            SongDTO(title: "Song Three", artist: "Artist C", firstLine: "First", filename: "song_three", reference: "", categories: [])
        ]
        
        try dataManager.populate(dataManager.container, with: songs, favorites: ["song_one", "song_three"])
        
        let favorites = dataManager.fetchFavoriteFilenames()
        
        XCTAssertEqual(favorites.count, 2)
        XCTAssertTrue(favorites.contains("song_one"))
        XCTAssertTrue(favorites.contains("song_three"))
        XCTAssertFalse(favorites.contains("song_two"))
    }
    
    func testCategoriesCreated() throws {
        let songs = [
            SongDTO(title: "Song", artist: "Artist", firstLine: "First", filename: "song", reference: "", categories: ["Category A", "Category B"])
        ]
        
        try dataManager.populate(dataManager.container, with: songs, favorites: [])
        
        let categories = dataManager.fetchAllCategories()
        let categoryNames = Set(categories.compactMap { $0.name })
        
        XCTAssertTrue(categoryNames.contains("Category A"))
        XCTAssertTrue(categoryNames.contains("Category B"))
    }
    
    func testCategoriesReused() throws {
        let songs = [
            SongDTO(title: "Song One", artist: "Artist", firstLine: "First", filename: "song_one", reference: "", categories: ["SharedCat"]),
            SongDTO(title: "Song Two", artist: "Artist", firstLine: "First", filename: "song_two", reference: "", categories: ["SharedCat"])
        ]
        
        try dataManager.populate(dataManager.container, with: songs, favorites: [])
        
        let categories = dataManager.fetchAllCategories()
        let sharedCategories = categories.filter { $0.name == "SharedCat" }
        
        XCTAssertEqual(sharedCategories.count, 1, "Category should be reused, not duplicated")
    }
    
    func testFlushDatabase() throws {
        let songs = [
            SongDTO(title: "Song", artist: "Artist", firstLine: "First", filename: "song", reference: "", categories: ["Cat"])
        ]
        
        try dataManager.populate(dataManager.container, with: songs, favorites: [])
        XCTAssertEqual(dataManager.fetchAllSongs().count, 1)
        
        try dataManager.flushDatabase(dataManager.container)
        
        XCTAssertEqual(dataManager.fetchAllSongs().count, 0)
        XCTAssertEqual(dataManager.fetchAllCategories().count, 0)
    }
    
    func testReferenceFieldStored() throws {
        let songs = [
            SongDTO(title: "Song", artist: "Artist", firstLine: "First", filename: "song", reference: "My Reference", categories: [])
        ]
        
        try dataManager.populate(dataManager.container, with: songs, favorites: [])
        
        let fetched = dataManager.fetchAllSongs().first
        XCTAssertEqual(fetched?.reference, "My Reference")
    }
}

