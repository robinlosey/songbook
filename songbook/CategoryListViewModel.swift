//
//  CategoryListViewModel.swift
//  songbook
//
//  Created by acemavrick on 6/7/25.
//

import Foundation
import CoreData
import Combine
import os.log

@MainActor
class CategoryListViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var totalSongs: Int = 0

    // lazy-loaded song counts with loading states
    @Published var songCounts: [NSManagedObjectID: Int?] = [:]  // nil means loading

    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CategoryListViewModel")
    private let dataManager: DataManager
    private var cancellables = Set<AnyCancellable>()
    private var countFetchTasks: [NSManagedObjectID: Task<Void, Never>] = [:]

    // computed to always use current container after A/B swaps
    var viewContext: NSManagedObjectContext {
        dataManager.container.viewContext
    }

    init(dataManager: DataManager = .shared) {
        self.dataManager = dataManager
        fetchCategories()
        getTotalSongs()

        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.invalidateCounts()
                self?.fetchCategories()
                self?.getTotalSongs()
            }
            .store(in: &cancellables)

        // refresh after A/B database swap
        NotificationCenter.default.publisher(for: .databaseDidSwitch, object: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Self.logger.info("Database switched - refreshing categories")
                self?.invalidateCounts()
                self?.fetchCategories()
                self?.getTotalSongs()
            }
            .store(in: &cancellables)
    }

    func getTotalSongs() {
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        do {
            totalSongs = try viewContext.count(for: request)
        } catch {
            CategoryListViewModel.logger.error("Error fetching total songs: \(error.localizedDescription)")
            totalSongs = 0
        }
    }

    func fetchCategories() {
        // check query cache first
        if let cached = dataManager.queryCache.getCachedCategories() {
            self.categories = cached
            Self.logger.debug("Using cached categories (\(cached.count) items)")
            for category in cached {
                _ = getSongCount(for: category)
            }
            return
        }

        // cache miss - fetch from database
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        let sortDescriptor = NSSortDescriptor(keyPath: \Category.name, ascending: true)
        request.sortDescriptors = [sortDescriptor]

        do {
            let fetchedCategories = try viewContext.fetch(request)
            self.categories = fetchedCategories
            dataManager.queryCache.setCachedCategories(fetchedCategories)

            for category in fetchedCategories {
                _ = getSongCount(for: category)
            }
        } catch {
            CategoryListViewModel.logger.error("Error fetching categories: \(error.localizedDescription)")
            self.categories = []
        }
    }

    /// returns song count for a category, fetching lazily if not cached
    /// returns nil if loading (shows spinner in ui)
    func getSongCount(for category: Category) -> Int? {
        let categoryID = category.objectID

        // check if we already have it (computed or loading)
        if let existing = songCounts[categoryID] {
            return existing
        }

        // check cache first
        if let cached = dataManager.queryCache.getCachedSongCount(for: categoryID) {
            songCounts[categoryID] = cached
            return cached
        }

        let categoryName = category.name

        // defer state update to avoid publishing changes during view updates
        Task { @MainActor [weak self] in
            guard let self else { return }
            
            // check again in case it was set while we were waiting
            guard self.songCounts[categoryID] == nil else { return }
            
            // mark as loading
            self.songCounts[categoryID] = nil

            // cancel any existing task for this category
            self.countFetchTasks[categoryID]?.cancel()

            // fetch count async
            let task = Task { [weak self] in
                guard let self else { return }

                let count = self.computeSongCount(for: categoryID, name: categoryName)

                self.songCounts[categoryID] = count
                self.dataManager.queryCache.setCachedSongCount(count, for: categoryID)
                self.countFetchTasks.removeValue(forKey: categoryID)
            }

            self.countFetchTasks[categoryID] = task
        }
        
        return nil
    }

    private func computeSongCount(for categoryID: NSManagedObjectID, name: String?) -> Int {
        guard let category = try? viewContext.existingObject(with: categoryID) as? Category else {
            Self.logger.error("Failed to retrieve category object for count")
            return 0
        }

        let request: NSFetchRequest<Song> = Song.fetchRequest()
        request.predicate = NSPredicate(format: "ANY categories == %@", category)

        do {
            let count = try viewContext.count(for: request)
            Self.logger.debug("Computed song count for '\(name ?? "Unknown")': \(count)")
            return count
        } catch {
            Self.logger.error("Error counting songs for category: \(error.localizedDescription)")
            return 0
        }
    }

    private func invalidateCounts() {
        songCounts.removeAll()
        countFetchTasks.values.forEach { $0.cancel() }
        countFetchTasks.removeAll()
    }

}

class PreviewCategoryListViewModel: CategoryListViewModel {
    init() {
        super.init(dataManager: DataManager.preview)
        if categories.isEmpty {
            CategoryListViewModel.logger.warning("Preview ContextViewModel categories should be initialized with sample data by DataManager.preview, but is empty.")
        }
    }
}
