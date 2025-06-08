//
//  SongListViewModel.swift
//  songbook
//
//  Created by acemavrick on 6/6/25.
//

import Foundation
import CoreData
import Combine

class SongListViewModel: ObservableObject {
    @Published var songs: [Song] = []
    private var cancellables = Set<AnyCancellable>()
    let viewContext: NSManagedObjectContext
    let category: Category?

    init(context: NSManagedObjectContext = DataManager.shared.container.viewContext,
         category: Category? = nil) {
        self.viewContext = context
        self.category = category
        fetchSongs()
    }

    func fetchSongs() {
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        let sortDescriptor = NSSortDescriptor(keyPath: \Song.title, ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        // if a category is provided, filter songs by that category
        if let category = category {
            request.predicate = NSPredicate(format: "ANY categories == %@", category)
        }
        
        do {
            songs = try viewContext.fetch(request)
            print("Fetched \(songs.count) songs for category: '\(category?.name ?? "All Songs")'")
        } catch {
            print("Error fetching songs for ViewModel: \(error.localizedDescription)")
            songs = []
        }
    }
    
    func toggleFavorite(for song: Song) {
        song.isFavorite.toggle()
        do {
            try viewContext.save()
            print("Toggled favorite status for song: \(song.title ?? "Unknown") to \(song.isFavorite)")
        } catch {
            print("Error saving favorite status: \(error.localizedDescription)")
        }
    }
}

// For Previews, if you want to use the In-Memory store with sample data:
class PreviewSongListViewModel: SongListViewModel {
    @MainActor
    init(category: Category? = nil) {
        // Use the preview DataManager's context
        super.init(context: DataManager.preview.container.viewContext, category: category)
        
        if songs.isEmpty && viewContext === DataManager.preview.container.viewContext {
             print("Preview ViewModel initialized, songs array is empty. DataManager.preview should have populated some items.")
        }
    }
} 
