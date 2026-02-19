//
//  FloatingNavigationPanel.swift
//  songbook
//
//  Floating Stage Manager-style navigation panel for iPad.
//

import SwiftUI

struct FloatingNavigationPanel: View {
    @ObservedObject var viewModel: CategoryListViewModel
    @Binding var selectedSong: Song?
    @Binding var showPanel: Bool
    @Binding var showSettings: Bool

    @State private var navigationPath = NavigationPath()
    @State private var dragOffset: CGFloat = 0

    private let panelWidth: CGFloat = 360
    private let maxPanelHeight: CGFloat = 700

    var body: some View {
        NavigationStack(path: $navigationPath) {
            PanelCategoryListView(
                viewModel: viewModel,
                navigationPath: $navigationPath
            )
            .navigationDestination(for: Category.self) { category in
                PanelSongListView(
                    category: category,
                    selectedSong: $selectedSong,
                    showPanel: $showPanel
                )
            }
            .navigationDestination(for: String.self) { identifier in
                if identifier == "all" {
                    PanelSongListView(
                        category: nil,
                        selectedSong: $selectedSong,
                        showPanel: $showPanel
                    )
                }
            }
            .scrollContentBackground(.hidden)
        }
        .frame(width: panelWidth)
        .frame(maxHeight: maxPanelHeight)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
        .padding(.leading, 24)
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width < 0 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width < -100 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showPanel = false
                        }
                    }
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                }
        )
    }
}

#Preview {
    ZStack(alignment: .leading) {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        FloatingNavigationPanel(
            viewModel: PreviewCategoryListViewModel(),
            selectedSong: .constant(nil),
            showPanel: .constant(true),
            showSettings: .constant(false)
        )
    }
    .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
    .environment(SyncManager.shared)
}
