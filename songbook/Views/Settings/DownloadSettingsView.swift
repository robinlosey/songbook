//
//  DownloadSettingsView.swift
//  songbook
//
//  Download and sync behavior settings.
//

import SwiftUI

struct DownloadSettingsView: View {
    @Environment(SyncManager.self) private var syncManager
    @AppStorage("autoDownloadAudio") private var autoDownload = true
    @AppStorage("autoDownloadOnCellular") private var autoDownloadOnCellular = false
    @State private var isRefreshing = false
    @State private var refreshResult: RefreshResult?

    enum RefreshResult {
        case success
        case failure
    }

    var body: some View {
        Form {
            Section {
                Toggle("Auto-download audio", isOn: $autoDownload)

                if autoDownload {
                    Toggle("Auto-download on cellular", isOn: $autoDownloadOnCellular)
                }
            } footer: {
                if autoDownload {
                    Text("Automatically download audio files in the background. On-demand downloads ignore these settings.")
                } else {
                    Text("Audio will only download when you tap the download button on a song.")
                }
            }
            .tint(AppColor.color2)

            Section {
                Button {
                    refreshLibrary()
                } label: {
                    HStack {
                        Text("Refresh Library")
                            .foregroundStyle(.primary)

                        Spacer()

                        if isRefreshing {
                            ProgressView()
                        } else if let result = refreshResult {
                            Image(systemName: result == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result == .success ? AppColor.tertiary : AppColor.destructive)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(isRefreshing)
            } footer: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Check for updates to the song library.")

                    if let checked = syncManager.lastCheckedDate {
                        Text("Last checked: \(checked.formatted(date: .abbreviated, time: .shortened))")
                    }

                    if let updated = syncManager.lastUpdatedDate {
                        Text("Last updated: \(updated.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
            }
        }
        .navigationTitle("Downloads")
        .animation(.default, value: autoDownload)
    }

    private func refreshLibrary() {
        isRefreshing = true
        refreshResult = nil

        Task {
            await syncManager.sync()

            // check result
            let result: RefreshResult
            if let status = syncManager.lastSyncStatus {
                result = status.result == .failed ? .failure : .success
            } else {
                result = .failure
            }

            withAnimation {
                isRefreshing = false
                refreshResult = result
            }

            // clear result after delay
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                refreshResult = nil
            }
        }
    }
}

#Preview {
    NavigationStack {
        DownloadSettingsView()
    }
    .environment(SyncManager.shared)
}
