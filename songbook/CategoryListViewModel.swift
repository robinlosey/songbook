//
//  CategoryListViewModel.swift
//  songbook
//
//  Created by acemavrick on 6/7/25.
//

import Foundation
import CoreData
import Combine

class CategoryListViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var totalSongs: Int = 0
    
    let viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext = DataManager.shared.container.viewContext) {
        self.viewContext = context
        fetchCategories()
        getTotalSongs()
        
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
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
            print("Error fetching total songs: \(error.localizedDescription)")
            totalSongs = 0
        }
    }

    func fetchCategories() {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        let sortDescriptor = NSSortDescriptor(keyPath: \Category.name, ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        do {
            categories = try viewContext.fetch(request)
        } catch {
            print("Error fetching categories: \(error.localizedDescription)")
            categories = []
        }
    }
    
}

class PreviewCategoryListViewModel: CategoryListViewModel {
    @MainActor
    init() {
        super.init(context: DataManager.preview.container.viewContext)
        if categories.isEmpty && viewContext === DataManager.preview.container.viewContext {
            print("Preview ContextViewModel categories should be initialized with sample data by DataManager.preview, but is empty.")
        }
    }
} 
