//
//  iPadRootView.swift
//  songbook
//
//  iPad root view with full-screen PDF and floating navigation panel.
//

import SwiftUI

struct iPadRootView: View {
    @ObservedObject var viewModel: CategoryListViewModel
    @State private var showPanel = true
    @State private var selectedSong: Song?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                // full-screen PDF (or empty state)
                Group {
                    if let song = selectedSong {
                        SongView(song: song) {
                            withAnimation {
                                song.isFavorite.toggle()
                                try? song.managedObjectContext?.save()
                            }
                        }
                    } else {
                        iPadEmptyStateView(showPanel: $showPanel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // dim scrim when panel is open
                if showPanel {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showPanel = false
                            }
                        }
                }

                // floating navigation panel
                if showPanel {
                    FloatingNavigationPanel(
                        viewModel: viewModel,
                        selectedSong: $selectedSong,
                        showPanel: $showPanel,
                        showSettings: $showSettings
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showPanel.toggle()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsPlaceholderView()
        }
        .gesture(
            // swipe from left edge to open panel
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.startLocation.x < 50 && value.translation.width > 50 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showPanel = true
                        }
                    }
                }
        )
    }
}

// MARK: - Empty State

struct iPadEmptyStateView: View {
    @Binding var showPanel: Bool

    var body: some View {
        ContentUnavailableView {
            Label("No Song Selected", systemImage: "music.note")
        } description: {
            Text("Select a song from the navigation panel to view it here")
        } actions: {
            Button("Open Navigation") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showPanel = true
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    iPadRootView(viewModel: PreviewCategoryListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
        .environment(SyncManager.shared)
        .environmentObject(AudioPlayerViewModel())
}
