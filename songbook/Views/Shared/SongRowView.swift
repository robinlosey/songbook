//
//  SongRowView.swift
//  songbook
//
//  Extracted from SongListView - reusable song row component.
//

import SwiftUI

/// displays category tags in a horizontal scroll (will be refactored to wrap in Phase 4)
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
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

struct SongRowView: View {
    @ObservedObject var song: Song
    var toggleFavoriteAction: () -> Void

    private var sortedCategories: [Category] {
        (song.categories?.allObjects as? [Category])?.sorted {
            ($0.name ?? "") < ($1.name ?? "")
        } ?? []
    }

    var body: some View {
        HStack {
            Button(action: toggleFavoriteAction) {
                Image(systemName: song.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(song.isFavorite ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title ?? "Untitled Song")
                    .font(.headline)
                Text(song.artist ?? "Unknown Artist")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(song.first_line ?? "")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                // category tags (horizontal scroll for now, will wrap in Phase 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    TagGroupView(tags: sortedCategories)
                }
            }
        }
    }
}

#Preview {
    List {
        SongRowView(song: Song(entity: Song.entity(), insertInto: DataManager.preview.container.viewContext)) {
            print("Toggle favorite")
        }
    }
    .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
}
