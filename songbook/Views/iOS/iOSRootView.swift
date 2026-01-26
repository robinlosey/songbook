//
//  iOSRootView.swift
//  songbook
//
//  iPhone root view with NavigationStack.
//

import SwiftUI

struct iOSRootView: View {
    @StateObject var viewModel: CategoryListViewModel
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            iOSCategoryListView(viewModel: viewModel, showSettings: $showSettings)
        }
        .sheet(isPresented: $showSettings) {
            // placeholder settings view until Phase 6
            SettingsPlaceholderView()
        }
    }
}

/// temporary placeholder until full settings are built in Phase 6
struct SettingsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("General", systemImage: "gear")
                    Label("Downloads", systemImage: "arrow.down.circle")
                    Label("Storage", systemImage: "internaldrive")
                }

                Section {
                    Label("About", systemImage: "info.circle")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    iOSRootView(viewModel: PreviewCategoryListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
        .environment(SyncManager.shared)
}
