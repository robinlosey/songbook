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
    @State private var syncManager = SyncManager.shared
    @StateObject private var audioPlayer = AudioPlayerViewModel()
    
    init() {
        // start network monitoring early
        NetworkMonitor.shared.start()
        
        // ensure database is populated from bundled CSV before UI appears
        DataManager.shared.ensureInitialDatabase()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: CategoryListViewModel())
                .environment(\.managedObjectContext, DataManager.shared.container.viewContext)
                .environment(syncManager)
                .environmentObject(audioPlayer)
                .task {
                    await syncManager.sync()
                }
        }
    }
}
