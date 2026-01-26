//
//  SettingsView.swift
//  songbook
//
//  Root settings view with navigation to sub-sections.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        GeneralSettingsView()
                    } label: {
                        Label("General", systemImage: "gear")
                    }

                    NavigationLink {
                        DownloadSettingsView()
                    } label: {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }

                    NavigationLink {
                        StorageView()
                    } label: {
                        Label("Storage", systemImage: "internaldrive")
                    }
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents(sizeClass == .regular ? [.medium, .large] : [.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(colorScheme)
    }
}

#Preview {
    SettingsView()
        .environment(SyncManager.shared)
}
