//
//  ContentView.swift
//  songbook
//
//  Created by acemavrick on 6/4/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject var viewModel: CategoryListViewModel
    var body: some View {
        CategoryListView(viewModel: viewModel)
    }
}

#Preview {
    ContentView(viewModel: PreviewCategoryListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
}
