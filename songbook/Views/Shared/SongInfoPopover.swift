//
//  SongInfoPopover.swift
//  songbook
//
//  Displays detailed information about a song (metadata, first line, tags).
//

import SwiftUI

struct SongInfoPopover: View {
    @ObservedObject var song: Song
    
    private var sortedCategories: [Category] {
        (song.categories?.allObjects as? [Category])?.sorted {
            ($0.name ?? "") < ($1.name ?? "")
        } ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            // Header
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack {
                    Text(song.title ?? "Untitled")
                        .font(AppFont.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    if song.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(AppColor.color4)
                            .font(AppFont.subheadline)
                    }
                }

                Text(song.artist ?? "Unknown Artist")
                    .font(AppFont.body)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // First Line
            if let firstLine = song.first_line, !firstLine.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Label("First Line", systemImage: "music.mic")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("“\(firstLine)”")
                        .font(AppFont.body.italic())
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Tags
            if !sortedCategories.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Label("Categories", systemImage: "tag")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                    
                    TagFlowView(tags: sortedCategories, maxVisible: 100)
                }
            }
            
            // Reference info (ID or Reference number if exists)
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Label("Reference", systemImage: "number")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                
                Text(song.reference ?? "Unknown ID")
                    .font(AppFont.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 280, maxWidth: 320)
    }
}

#Preview {
    let song: Song = {
        let context = DataManager.preview.container.viewContext
        let s = Song(entity: Song.entity(), insertInto: context)
        s.title = "Amazing Grace"
        s.artist = "John Newton"
        s.first_line = "Amazing grace! How sweet the sound"
        s.reference = "12345"
        
        let cat = Category(context: context)
        cat.name = "Hymns"
        s.addToCategories(cat)
        
        return s
    }()
    
    SongInfoPopover(song: song)
}
