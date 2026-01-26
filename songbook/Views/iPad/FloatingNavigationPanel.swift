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

    private let panelWidth: CGFloat = 320

    var body: some View {
        VStack(spacing: 0) {
            // navigation content
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
                    // "all" = All Songs
                    if identifier == "all" {
                        PanelSongListView(
                            category: nil,
                            selectedSong: $selectedSong,
                            showPanel: $showPanel
                        )
                    }
                }
            }

            Divider()

            // fixed footer with settings
            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "gear")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
        .frame(width: panelWidth)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 5, y: 0)
        .padding(.leading, 16)
        .padding(.vertical, 16)
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // only allow dragging left (to close)
                    if value.translation.width < 0 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    // if dragged far enough left, close panel
                    if value.translation.width < -100 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showPanel = false
                        }
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
