//
//  SongView.swift
//  songbook
//
//  Created by acemavrick on 6/5/25.
//

import SwiftUI

struct SongView: View {
    @ObservedObject var song: Song
    var toggleFavoriteAction: () -> Void
    
    private var sortedCategories: [Category] {
        guard let categories = song.categories as? Set<Category> else { return [] }
        return categories.sorted { $0.name ?? "" < $1.name ?? "" }
    }
    
    var body: some View {
        ZStack {
            PDFViewer(forSong: song.filename ?? "Unknown")
                .ignoresSafeArea(.all)
            
            VStack {
                HStack {
                    HStack{
                        ForEach(sortedCategories, id: \.self) { category in
                            Text(category.name ?? "Unknown Category")
                                .font(.caption)
                                .padding(5)
                                .background(Color.blue.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .foregroundStyle(.black)
                        }
                    }
                    .padding()
                    Spacer()
                    HStack {
                        Button(action: toggleFavoriteAction) {
                            Image(systemName: song.isFavorite ? "star.fill" : "star")
                                .foregroundColor(song.isFavorite ? .yellow : .gray)
                        }
                        .buttonStyle(.plain)
                        .padding(5)
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 5)
                    .padding()
                }
                Spacer()
            }
        }
    }
}
