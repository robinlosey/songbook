//
//  CategoryListView.swift
//  songbook
//
//  Created by acemavrick on 6/7/25.
//

import SwiftUI
import CoreData


struct CategoryRowView: View {
    let name: String?
    let count: Int?
    
    var body: some View {
        HStack {
            Text(name ?? "Unknown Category")
                .font(.headline)
            Spacer()
            if count != nil {
                Text("\(count!) Songs")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }
}

struct CategoryListView: View {
    @StateObject var viewModel: CategoryListViewModel

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    SongListView(viewModel: SongListViewModel())
                } label: {
                    CategoryRowView(name: "All Songs", count: nil)
                }
                ForEach(viewModel.categories, id: \.self) { category in
                    NavigationLink {
                        SongListView(viewModel: SongListViewModel(category: category))
                    } label: {
                        CategoryRowView(name: category.name, count: category.songs?.count)
                    }
                }
            }
            .navigationTitle("Categories")
        }
    }
}

#Preview {
    CategoryListView(viewModel: PreviewCategoryListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
} 
