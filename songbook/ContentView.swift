//
//  ContentView.swift
//  songbook
//
//  Created by acemavrick on 6/4/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    // Initialize the ViewModel directly or receive it from an environment object
    // depending on how you manage dependencies in your app.
    // For simplicity here, we create it directly.
    @StateObject var songListViewModel: SongListViewModel

    var body: some View {
        SongListView(viewModel: songListViewModel, previewMode: false)
    }
}

#Preview {
    ContentView(songListViewModel: SongListViewModel())
}
