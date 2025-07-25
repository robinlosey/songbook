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
    @State private var updateStatus: DataManager.UpdateStatus = DataManager.updateStatus

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    SongListView(viewModel: SongListViewModel())
                } label: {
                    CategoryRowView(name: "All Songs", count: viewModel.totalSongs)
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
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    HStack {
                        Text(String(UserDefaults.standard.integer(forKey: "storedCSVVersion")))
                        switch updateStatus {
                        case .notStarted:
                            Image(systemName: "minus")
                        case .updating:
                            Image(systemName: "circle.dotted.circle")
                        case .done:
                            Image(systemName: "checkmark")
                        }
                        Button {
                            Task {
                                await DataManager.shared.refreshAndUpdate()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(updateStatus == .updating)
                        .buttonStyle(.bordered)
                    }
                    .font(.footnote)
                }
            }
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            updateStatus = DataManager.updateStatus
        }
    }
}

#Preview {
    CategoryListView(viewModel: PreviewCategoryListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
} 
