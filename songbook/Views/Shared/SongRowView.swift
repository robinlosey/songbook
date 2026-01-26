//
//  SongRowView.swift
//  songbook
//
//  Reusable song row component with configurable tags.
//

import SwiftUI

struct SongRowView: View {
    @ObservedObject var song: Song
    var toggleFavoriteAction: () -> Void
    
    // Configurable setting for showing tags
    @AppStorage("showCategoryTags") private var showTags = true

    private var sortedCategories: [Category] {
        (song.categories?.allObjects as? [Category])?.sorted {
            ($0.name ?? "") < ($1.name ?? "")
        } ?? []
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Button(action: toggleFavoriteAction) {
                Image(systemName: song.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(song.isFavorite ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2) // Align with title text

            VStack(alignment: .leading, spacing: 4) {
                Text(song.title ?? "Untitled Song")
                    .font(AppFont.headline)
                    .foregroundStyle(.primary)
                
                Text(song.artist ?? "Unknown Artist")
                    .font(AppFont.subheadline)
                    .foregroundStyle(.secondary)

                if showTags && !sortedCategories.isEmpty {
                    TagFlowView(tags: sortedCategories)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
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
