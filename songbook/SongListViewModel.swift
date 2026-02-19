//
//  SongListViewModel.swift
//  songbook
//
//  Created by acemavrick on 6/6/25.
//

import Foundation
import CoreData
import Combine
import os.log

@MainActor
class SongListViewModel: ObservableObject {
    enum SortOption: String, CaseIterable, Identifiable {
        case title = "title"
        case artist = "artist"
        case firstLine = "firstLine"

        var id: String { self.rawValue }

        var sortDescriptor: NSSortDescriptor {
            switch self {
            case .title:
                return NSSortDescriptor(keyPath: \Song.title, ascending: true)
            case .artist:
                return NSSortDescriptor(keyPath: \Song.artist, ascending: true)
            case .firstLine:
                return NSSortDescriptor(keyPath: \Song.first_line, ascending: true)
            }
        }

        func sectionIdentifier(for song: Song) -> String {
            switch self {
            case .title:
                return String((song.title?.first ?? "#").uppercased())
            case .artist:
                return String((song.artist?.first ?? "#").uppercased())
            case .firstLine:
                return String((song.first_line?.first ?? "#").uppercased())
            }
        }

        // display name for UI
        var displayName: String {
            switch self {
            case .title: return "Title"
            case .artist: return "Artist"
            case .firstLine: return "First Line"
            }
        }
    }

    @Published var songs: [Song] = []
    @Published var sortBy: SortOption
    @Published var onlyFavorites: Bool = false
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false

    var sectionedSongs: [String: [Song]] {
        Dictionary(grouping: songs, by: { sortBy.sectionIdentifier(for: $0) })
    }

    var sortedSectionKeys: [String] {
        sectionedSongs.keys.sorted()
    }

    private var cancellables = Set<AnyCancellable>()
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SongListViewModel")
    private let dataManager: DataManager
    let category: Category?

    // computed to always use current container after A/B swaps
    var viewContext: NSManagedObjectContext {
        dataManager.container.viewContext
    }

    init(dataManager: DataManager = .shared, category: Category? = nil) {
        self.dataManager = dataManager
        self.category = category

        // initialize sort from user default
        let defaultSortKey = UserDefaults.standard.string(forKey: "defaultSortOrder") ?? "title"
        self.sortBy = SortOption(rawValue: defaultSortKey) ?? .title

        // observe changes to sortBy
        $sortBy
            .sink { [weak self] _ in
                self?.fetchSongs()
            }
            .store(in: &cancellables)

        // debounce search to avoid fetching on every keystroke
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchSongs()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.dataManager.queryCache.invalidateSongs()
                self?.fetchSongs()
            }
            .store(in: &cancellables)

        // refresh after A/B database swap
        NotificationCenter.default.publisher(for: .databaseDidSwitch, object: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Self.logger.info("Database switched - refreshing songs")
                self?.fetchSongs()
            }
            .store(in: &cancellables)

        fetchSongs()
    }

    func toggleOnlyFavorites() {
        onlyFavorites.toggle()
        fetchSongs()
    }

    func fetchSongs() {
        isLoading = true
        let categoryID = category?.objectID
        let categoryName = category?.name

        // check query cache first (skip when searching since it changes frequently)
        if searchText.isEmpty,
           let cached = dataManager.queryCache.getCachedSongs(for: categoryID, onlyFavorites: onlyFavorites) {
            songs = cached
            isLoading = false
            Self.logger
                .debug(
                    "Using cached songs (\(cached.count) items, favorites: \(self.onlyFavorites))"
                )
            return
        }

        let request: NSFetchRequest<Song> = Song.fetchRequest()
        request.sortDescriptors = [sortBy.sortDescriptor]

        var predicates: [NSPredicate] = []

        if let category = category {
            predicates.append(NSPredicate(format: "ANY categories == %@", category))
        }

        if onlyFavorites {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }

        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "title CONTAINS[cd] %@ OR artist CONTAINS[cd] %@ OR first_line CONTAINS[cd] %@", searchText, searchText, searchText))
        }

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        // cache miss - fetch from database
        do {
            let allSongs = try viewContext.fetch(request)

            // batch pdf availability check (10-100x faster than individual checks)
            let filenames = allSongs.compactMap { $0.filename }
            let availablePDFs = DataManager.getBatchPDFAvailability(for: filenames)

            // filter to only show songs with available pdfs
            let withPDF = allSongs.filter { song in
                guard let filename = song.filename else { return false }
                return availablePDFs.contains(filename)
            }

            songs = withPDF
            // only cache when not searching (search results are too transient)
            if searchText.isEmpty {
                dataManager.queryCache.setCachedSongs(withPDF, for: categoryID, onlyFavorites: onlyFavorites)
            }

            Self.logger.info("Fetched \(self.songs.count) songs with PDFs for category: '\(categoryName ?? "All Songs")'")
        } catch {
            Self.logger.error("Error fetching songs for ViewModel: \(error.localizedDescription)")
            songs = []
        }

        isLoading = false
    }

    func toggleFavorite(for song: Song) {
        song.isFavorite.toggle()
        do {
            try viewContext.save()
            SongListViewModel.logger.info("Toggled favorite status for song: \(song.title ?? "Unknown") to \(song.isFavorite)")
        } catch {
            SongListViewModel.logger.error("Error saving favorite status: \(error.localizedDescription)")
        }
    }
}

// for previews using in-memory store with sample data
class PreviewSongListViewModel: SongListViewModel {
    init(category: Category? = nil) {
        super.init(dataManager: DataManager.preview, category: category)

        if songs.isEmpty {
            SongListViewModel.logger.warning("Preview ViewModel initialized, songs array is empty. DataManager.preview should have populated some items.")
        }
    }
}
