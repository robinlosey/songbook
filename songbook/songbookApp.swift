//
//  songbookApp.swift
//  songbook
//
//  Created by acemavrick on 6/4/25.
//

import SwiftUI

@main
struct songbookApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
//            ContentView()
//                .environment(\.managedObjectContext, persistenceController.container.viewContext)
            PDFViewer(forSong: "Fort Tabarsi")
        }
    }
}
