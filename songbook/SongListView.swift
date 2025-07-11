//
//  SongListView.swift
//  songbook
//
//  Created by acemavrick on 6/6/25.
//

import SwiftUI
import CoreData

struct TagGroupView: View {
    var tags: [Category]
    
    var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            LazyHStack(spacing: 8) {
                ForEach(tags) { tag in
                    Text(tag.name ?? "Untitled Tag")
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.accent.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

struct SongRowView: View {
    @ObservedObject var song: Song
    var toggleFavoriteAction: () -> Void
    
    var body: some View {
        HStack {
            Button(action: toggleFavoriteAction) {
                Image(systemName: song.isFavorite ? "star.fill" : "star")
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title ?? "Untitled Song")
                    .font(.headline)
                Text(song.artist ?? "Unknown Artist")
                    .font(.subheadline)
                Text(song.first_line ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Tag Groups
                ScrollView(.horizontal, showsIndicators: false) {
                    TagGroupView(tags: (song.categories?.allObjects as? [Category]) ?? [])
                }
            }
        }
    }
}

struct SortPicker: View {
    @Binding var sortByBinding: SongListViewModel.SortOption
    
    var body: some View {
        HStack {
            Text("Sort By:")
            Picker("", selection: $sortByBinding) {
                ForEach(SongListViewModel.SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue.capitalized).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct SongSection: View {
    let sectionKey: String
    @ObservedObject var viewModel: SongListViewModel
    
    var body: some View {
        Section(header: Text(sectionKey)) {
            ForEach(viewModel.sectionedSongs[sectionKey] ?? []) { song in
                NavigationLink {
                    SongView(song: song) {
                        withAnimation {
                            viewModel.toggleFavorite(for: song)
                        }
                    }
                } label: {
                    SongRowView(song: song) {
                        withAnimation {
                            viewModel.toggleFavorite(for: song)
                        }
                    }
                } // end NavigationLink
            } // end ForEach
        } // end Section
    }
}

struct AlphabetIndexView: View {
    let keys: [String]
    let proxy: ScrollViewProxy
    @State private var activeKeyIndex: Int?
    private let rowHeight: CGFloat = 22

    private func scrollTo(keyIndex: Int) {
        if keyIndex >= 0 && keyIndex < keys.count {
            let key = keys[keyIndex]
            if activeKeyIndex != keyIndex {
                proxy.scrollTo(key, anchor: .top)
                activeKeyIndex = keyIndex
            }
        }
    }

    private func magnificationEffect(for index: Int) -> (scale: CGFloat, offset: CGFloat) {
        guard let activeKeyIndex = activeKeyIndex else {
            return (1.0, 0)
        }
        let distance = abs(index - activeKeyIndex)
        
        switch distance {
        case 0:
            return (1.8, -25) // Largest scale and offset for the active letter
        case 1:
            return (1.5, -15) // Smaller effect for immediate neighbors
        case 2:
            return (1.2, -5)  // Even smaller effect
        default:
            return (1.0, 0)   // No effect for letters further away
        }
    }

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 0) {
                ForEach(Array(keys.enumerated()), id: \.element) { index, key in
                    let (scale, offset) = magnificationEffect(for: index)
                    
                    Text(key)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                        .frame(width: 30, height: rowHeight)
                        .contentShape(Rectangle())
                        .scaleEffect(scale)
                        .offset(x: offset)
                        .zIndex(scale > 1.0 ? 1 : 0)
                }
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: activeKeyIndex)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let y = value.location.y
                        let index = Int(y / rowHeight)
                        let clampedIndex = max(0, min(keys.count - 1, index))
                        
                        scrollTo(keyIndex: clampedIndex)
                    }
                    .onEnded { _ in
                        activeKeyIndex = nil
                    }
            )
            .padding(.trailing, 2)
        }
    }
}

struct SongListView: View {
    @StateObject var viewModel: SongListViewModel
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(viewModel.sortedSectionKeys, id: \.self) { sectionKey in
                        SongSection(sectionKey: sectionKey, viewModel: viewModel)
                            .id(sectionKey)
                    } // end ForEach
                    
                    if (viewModel.songs.isEmpty) {
                        Text("No songs found.")
                    }
                } // end list
                .searchable(text: $viewModel.searchText)
                .overlay(
                    AlphabetIndexView(keys: viewModel.sortedSectionKeys, proxy: proxy)
                )
            }
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .navigationTitle(viewModel.category?.name ?? "All Songs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 5) {
                    SortPicker(sortByBinding: $viewModel.sortBy)
                    
                    Button {
                        withAnimation {
                            viewModel.toggleOnlyFavorites()
                        }
                    } label: {
//                        if viewModel.onlyFavorites {
//                            Label("Show All", systemImage: "chevron.compact.down")
//                        } else {
//                            Label("Show Favorites", systemImage: "star.fill")
//                        }
                        Image(systemName: viewModel.onlyFavorites ? "star.square.on.square.fill" : "star.square.on.square")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .labelStyle(.titleAndIcon)
                }
            } // end item
        } // end toolbar
    }
}

#Preview {
    SongListView(viewModel: PreviewSongListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
}
