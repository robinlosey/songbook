//
//  ContentView.swift
//  songbook
//
//  Created by acemavrick on 6/4/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    let availableSongs = ["Abdu\'l-Baha", "Baha\'u\'llah", "Blessed is the Spot EN", "Forgive Each Other", "Fort Tabarsi", "Fruits of One Tree", "Give Us Peace", "God is Sufficient Unto Me Elaine", "Good Neighbors Come in All Colors", "Hawaiian Unity Song HI", "Healing Prayer", "I am O MY God", "I Have Found Baha\'u\'llah", "I Love You", "Let Thy Heart be Dilated", "O Lord I Adore Thee", "Prayer for Youth", "Rose Garden Prayer", "Seven Martyrs of Tehran", "Siyahamb\'e", "Strive", "That is How Baha\'is Should Be", "We Shall Not Fail", "What Mankind Has to Learn"]
    @State private var selectedSong = "Fort Tabarsi"
    
    var body: some View {
        ZStack {
            PDFViewer(forSong: selectedSong)
            VStack {
                HStack {
                    Menu {
                        ForEach(availableSongs, id: \.self) { song in
                            Button(song) {
                                selectedSong = song
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedSong)
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.subheadline)
                        }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.primary, lineWidth: 1)
                            )
                            .padding()
                        
                    }
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

#Preview {
    ContentView()
}
