//
//  StorageView.swift
//  songbook
//
//  Manage downloaded audio files and storage usage.
//

import SwiftUI

struct StorageView: View {
    @StateObject private var viewModel = StorageViewModel()
    @State private var showDeleteAllConfirmation = false

    var body: some View {
        List {
            // summary section
            Section {
                HStack {
                    Label("Audio Files", systemImage: "waveform")
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text(viewModel.formattedTotalSize)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Label("Files", systemImage: "doc")
                    Spacer()
                    Text("\(viewModel.downloadedFiles.count)")
                        .foregroundStyle(.secondary)
                }
            }

            // downloaded files
            Section {
                if viewModel.downloadedFiles.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Downloaded audio files will appear here")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.downloadedFiles) { file in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(file.title)
                                    .font(AppFont.body)
                                Text(file.id)
                                    .font(AppFont.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text(file.formattedSize)
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { viewModel.deleteFile(at: $0) }
                }
            } header: {
                Text("Downloaded Audio")
            }

            // delete all
            if !viewModel.downloadedFiles.isEmpty {
                Section {
                    Button("Delete All Audio", role: .destructive) {
                        showDeleteAllConfirmation = true
                    }
                }
            }
        }
        .navigationTitle("Storage")
        .refreshable {
            viewModel.loadDownloadedAudio()
        }
        .confirmationDialog(
            "Delete All Audio?",
            isPresented: $showDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                viewModel.deleteAllAudio()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete \(viewModel.downloadedFiles.count) audio files (\(viewModel.formattedTotalSize)). You can re-download them later.")
        }
    }
}

#Preview {
    NavigationStack {
        StorageView()
    }
}
