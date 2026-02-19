//
//  QueryCacheTests.swift
//  tests
//
//  tests for querycache (@MainActor isolated)
//

import Testing
import CoreData
@testable import songbook

@Suite("QueryCache Tests")
@MainActor
struct QueryCacheTests {

    let queryCache: QueryCache
    let dataManager: DataManager

    init() {
        dataManager = DataManager.inMemory()
        queryCache = dataManager.queryCache
    }

    @Test("song cache hit and miss behavior")
    func songCacheHitAndMiss() {
        let testSong = Song(context: dataManager.container.viewContext)
        testSong.title = "Test Song"
        testSong.filename = "test"

        let miss = queryCache.getCachedSongs(for: nil)
        #expect(miss == nil)

        queryCache.setCachedSongs([testSong], for: nil)

        let hit = queryCache.getCachedSongs(for: nil)
        #expect(hit != nil)
        #expect(hit?.count == 1)
        #expect(hit?.first?.title == "Test Song")
    }

    @Test("song cache expires after duration")
    func songCacheExpiration() async throws {
        // create a separate cache with short expiry for this test
        let shortCache = QueryCache(cacheValidDuration: 0.1)

        let testSong = Song(context: dataManager.container.viewContext)
        testSong.title = "Test Song"

        shortCache.setCachedSongs([testSong], for: nil)

        let hit1 = shortCache.getCachedSongs(for: nil)
        #expect(hit1 != nil)

        try await Task.sleep(for: .milliseconds(150))

        let hit2 = shortCache.getCachedSongs(for: nil)
        #expect(hit2 == nil)
    }

    @Test("song cache is isolated per category")
    func songCachePerCategory() {
        let category1 = Category(context: dataManager.container.viewContext)
        category1.name = "Cat1"

        let category2 = Category(context: dataManager.container.viewContext)
        category2.name = "Cat2"

        let song1 = Song(context: dataManager.container.viewContext)
        song1.title = "Song 1"

        let song2 = Song(context: dataManager.container.viewContext)
        song2.title = "Song 2"

        queryCache.setCachedSongs([song1], for: category1.objectID)
        queryCache.setCachedSongs([song2], for: category2.objectID)

        let cat1Songs = queryCache.getCachedSongs(for: category1.objectID)
        #expect(cat1Songs?.count == 1)
        #expect(cat1Songs?.first?.title == "Song 1")

        let cat2Songs = queryCache.getCachedSongs(for: category2.objectID)
        #expect(cat2Songs?.count == 1)
        #expect(cat2Songs?.first?.title == "Song 2")
    }

    @Test("category cache hit and miss behavior")
    func categoryCacheHitAndMiss() {
        let testCategory = Category(context: dataManager.container.viewContext)
        testCategory.name = "Test Category"

        let miss = queryCache.getCachedCategories()
        #expect(miss == nil)

        queryCache.setCachedCategories([testCategory])

        let hit = queryCache.getCachedCategories()
        #expect(hit != nil)
        #expect(hit?.count == 1)
        #expect(hit?.first?.name == "Test Category")
    }

    @Test("song count cache stores and retrieves counts")
    func songCountCache() {
        let category = Category(context: dataManager.container.viewContext)
        category.name = "Test"

        let miss = queryCache.getCachedSongCount(for: category.objectID)
        #expect(miss == nil)

        queryCache.setCachedSongCount(42, for: category.objectID)

        let hit = queryCache.getCachedSongCount(for: category.objectID)
        #expect(hit == 42)
    }

    @Test("invalidate all clears everything")
    func invalidateAll() {
        let song = Song(context: dataManager.container.viewContext)
        let category = Category(context: dataManager.container.viewContext)

        queryCache.setCachedSongs([song], for: nil)
        queryCache.setCachedCategories([category])
        queryCache.setCachedSongCount(10, for: category.objectID)

        #expect(queryCache.getCachedSongs(for: nil) != nil)
        #expect(queryCache.getCachedCategories() != nil)
        #expect(queryCache.getCachedSongCount(for: category.objectID) != nil)

        queryCache.invalidateAll()

        #expect(queryCache.getCachedSongs(for: nil) == nil)
        #expect(queryCache.getCachedCategories() == nil)
        #expect(queryCache.getCachedSongCount(for: category.objectID) == nil)
    }

    @Test("invalidate songs only preserves categories")
    func invalidateSongsOnly() {
        let song = Song(context: dataManager.container.viewContext)
        let category = Category(context: dataManager.container.viewContext)

        queryCache.setCachedSongs([song], for: nil)
        queryCache.setCachedCategories([category])

        queryCache.invalidateSongs()

        #expect(queryCache.getCachedSongs(for: nil) == nil)
        #expect(queryCache.getCachedCategories() != nil)
    }

    @Test("invalidate categories clears counts too")
    func invalidateCategoriesOnly() {
        let song = Song(context: dataManager.container.viewContext)
        let category = Category(context: dataManager.container.viewContext)

        queryCache.setCachedSongs([song], for: nil)
        queryCache.setCachedCategories([category])
        queryCache.setCachedSongCount(5, for: category.objectID)

        queryCache.invalidateCategories()

        #expect(queryCache.getCachedCategories() == nil)
        #expect(queryCache.getCachedSongCount(for: category.objectID) == nil)
        #expect(queryCache.getCachedSongs(for: nil) != nil)
    }

    @Test("statistics track cache sizes correctly")
    func statistics() {
        let category = Category(context: dataManager.container.viewContext)
        let song = Song(context: dataManager.container.viewContext)

        queryCache.setCachedCategories([category])
        queryCache.setCachedSongs([song], for: nil)
        queryCache.setCachedSongs([song], for: category.objectID)
        queryCache.setCachedSongCount(1, for: category.objectID)

        let stats = queryCache.getStatistics()

        #expect(stats.categoryCacheSize == 1)
        #expect(stats.songCacheSize == 2)
        #expect(stats.songCountCacheSize == 1)
    }
}
