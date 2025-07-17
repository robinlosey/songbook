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
        let dm = dataManager
        Task {
             await dm.refreshAndUpdate()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: CategoryListViewModel())
                .environment(\.managedObjectContext, dataManager.container.viewContext)
                .environmentObject(audioPlayer)
        }
    }
}
