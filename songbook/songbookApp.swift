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
