//
//  songbookApp.swift
//  songbook
//
//  Created by acemavrick on 6/4/25.
//

import SwiftUI

@main
struct songbookApp: App {
    let dataManager = DataManager.shared

    init() {
        // Load songs from CSV when the app initializes, if they haven't been loaded already.
        dataManager.loadSongsFromCSVIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(songListViewModel: SongListViewModel())
                .environment(\.managedObjectContext, dataManager.container.viewContext)
        }
    }
}
