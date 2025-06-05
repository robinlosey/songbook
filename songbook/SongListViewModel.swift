//
//  SongListViewModel.swift
//  songbook
//
//  Created by Gemini Assistant on 6/6/25.
//

import Foundation
import CoreData
import Combine

class SongListViewModel: ObservableObject {
    @Published var songs: [Song] = []
    private var cancellables = Set<AnyCancellable>()
    let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext = DataManager.shared.container.viewContext) {
        self.viewContext = context
        fetchSongs()
    }

    func fetchSongs() {
        let request: NSFetchRequest<Song> = Song.fetchRequest()
        let sortDescriptor = NSSortDescriptor(keyPath: \Song.title, ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        do {
            songs = try viewContext.fetch(request)
            print("Fetched \(songs.count) songs for the ViewModel.")
        } catch {
            print("Error fetching songs for ViewModel: \(error.localizedDescription)")
            // Handle the error appropriately in a production app
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
    init() {
        // Use the preview DataManager's context
        super.init(context: DataManager.preview.container.viewContext)
        
        if songs.isEmpty && viewContext === DataManager.preview.container.viewContext {
             print("Preview ViewModel initialized, songs array is empty. DataManager.preview should have populated some items.")
        }
    }
} 
