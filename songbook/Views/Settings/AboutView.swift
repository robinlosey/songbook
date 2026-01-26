//
//  AboutView.swift
//  songbook
//
//  App version, library info, and debug details.
//

import SwiftUI

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(SyncManager.self) private var syncManager

    var body: some View {
        List {
            Section("App") {
                LabeledContent("Version", value: Bundle.main.appVersion)
                LabeledContent("Build", value: Bundle.main.buildNumber)
            }

            Section("Library") {
                LabeledContent("Data Version", value: "\(syncManager.currentVersion)")

                if let status = syncManager.lastSyncStatus {
                    LabeledContent("Last Sync", value: status.timestamp.formatted(date: .abbreviated, time: .shortened))

                    LabeledContent("Sync Result") {
                        HStack(spacing: 4) {
                            Image(systemName: statusIcon(for: status.result))
                                .foregroundStyle(statusColor(for: status.result))
                            Text(statusText(for: status.result))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                DisclosureGroup("Debug Info") {
                    LabeledContent("Current DB", value: DataManager.shared.currentStore)
                    LabeledContent("Bundled Version", value: "\(DataManager.bundledCSVVersion)")

                    if let status = syncManager.lastSyncStatus {
                        LabeledContent("From Version", value: "\(status.fromVersion)")
                        if let toVersion = status.toVersion {
                            LabeledContent("To Version", value: "\(toVersion)")
                        }
                        if let error = status.errorMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Error")
                                    .font(AppFont.caption)
                                    .foregroundStyle(.secondary)
                                Text(error)
                                    .font(AppFont.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("About")
    }

    // MARK: - Status Helpers

    private func statusIcon(for result: SyncStatus.Result) -> String {
        switch result {
        case .success: return "checkmark.circle.fill"
        case .noUpdateNeeded: return "checkmark.circle"
        case .failed: return "xmark.circle.fill"
        }
    }

    private func statusColor(for result: SyncStatus.Result) -> Color {
        switch result {
        case .success: return .green
        case .noUpdateNeeded: return .secondary
        case .failed: return .red
        }
    }

    private func statusText(for result: SyncStatus.Result) -> String {
        switch result {
        case .success: return "Updated"
        case .noUpdateNeeded: return "Up to date"
        case .failed: return "Failed"
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
    .environment(SyncManager.shared)
}
