//
//  ContentView.swift
//  songbook
//
//  Created by acemavrick on 6/4/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject var songListViewModel: SongListViewModel

    var body: some View {
        SongListView(viewModel: songListViewModel)
    }
}

#Preview {
    ContentView(songListViewModel: SongListViewModel())
}
