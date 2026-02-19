//
//  GeneralSettingsView.swift
//  songbook
//
//  General app settings: appearance, list display, audio defaults.
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("showCategoryTags") private var showTags = true
    @AppStorage("defaultSortOrder") private var defaultSort = "title"
    @AppStorage("hideAudioControlsByDefault") private var hideAudioByDefault = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker(selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                } label: {
                    Text("Theme")
                }
            }

            Section("Song List") {
                Toggle("Show category tags", isOn: $showTags)

                Picker("Default sort", selection: $defaultSort) {
                    Text("Title").tag("title")
                    Text("Artist").tag("artist")
                    Text("First Line").tag("firstLine")
                }
            }

            Section {
                Toggle("Hide audio controls by default", isOn: $hideAudioByDefault)
            } header: {
                Text("Audio")
            } footer: {
                Text("When enabled, audio controls are hidden until you tap the music note button.")
            }
        }
        .navigationTitle("General")
    }
}

#Preview {
    NavigationStack {
        GeneralSettingsView()
    }
}
