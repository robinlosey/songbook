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
    var body: some View {
        ZStack {
            PDFViewer(forSong: song.filename ?? "Unknown")
                .ignoresSafeArea(.all)
            
            VStack {
                HStack {
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
