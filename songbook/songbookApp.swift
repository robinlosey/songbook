//
//  songbookApp.swift
//  songbook
//
//  Created by acemavrick on 6/4/25.
//

import SwiftUI
import AVFoundation

@main
struct songbookApp: App {
    let dataManager = DataManager.shared
    @StateObject var audioPlayer = AudioPlayerViewModel()

    init() {
        // Load songs from CSV when the app initializes, if they haven't been loaded already.
        dataManager.loadSongsFromCSVIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: CategoryListViewModel())
                .environment(\.managedObjectContext, dataManager.container.viewContext)
                .environmentObject(audioPlayer)
        }
    }
}
