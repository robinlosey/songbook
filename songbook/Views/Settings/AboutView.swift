//
//  AboutView.swift
//  songbook
//
//  App information, credits, library info, and debug details.
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

    var appName: String {
        infoDictionary?["CFBundleDisplayName"] as? String
            ?? infoDictionary?["CFBundleName"] as? String
            ?? "Songbook"
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(SyncManager.self) private var syncManager

    var body: some View {
        List {
            // app header with icon
            Section {
                VStack(spacing: AppSpacing.medium) {
                    // app icon
                    AppIconView()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                    // app name and version
                    VStack(spacing: 2) {
                        Text(Bundle.main.appName)
                            .font(AppFont.title2.weight(.semibold))

                        Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.medium)
                .listRowBackground(Color.clear)
            }

            // about / description
            Section("About") {
                Text("""
                    A musical gathering place with 130+ songs inspired by the principles and Writings of the Baháʼí Faith. Each song includes the score, lyrics, chords, guitar diagrams, and an MP3 to listen or play along.
                    
                    Compiled by Elaine Losey and Beth King-Mock; developed by Robin Losey and Shubh Randeria. App code is open source and free to use as a template.
                    
                    With gratitude to the composers who shared their work. All music remains their copyright and appears here with permission whenever contact was possible.
                    """)
                    .font(AppFont.subheadline)
                    .foregroundStyle(.secondary)
            }

            // credits
//            Section("Credits") {
//                // developer can customize this
//                CreditRow(role: "Developer", name: "Your Name Here")
//                // add more credits as needed:
//                // CreditRow(role: "Design", name: "Designer Name")
//                // CreditRow(role: "Music", name: "Contributor Name")
//            }

            // library info
            Section("Library") {
                LabeledContent("Data Version", value: "\(syncManager.currentVersion)")

                if let checked = syncManager.lastCheckedDate {
                    LabeledContent {
                        Text(checked.formatted(date: .abbreviated, time: .shortened))
                    } label: {
                        Text("Last Checked")
                    }
                }

                if let updated = syncManager.lastUpdatedDate {
                    LabeledContent {
                        Text(updated.formatted(date: .abbreviated, time: .shortened))
                    } label: {
                        Text("Last Updated")
                    }
                }

                if let status = syncManager.lastSyncStatus {
                    LabeledContent {
                        HStack(spacing: 4) {
                            Image(systemName: statusIcon(for: status.result))
                                .foregroundStyle(statusColor(for: status.result))
                            Text(statusText(for: status.result))
                        }
                    } label: {
                        Text("Status")
                    }
                }
            }

            // debug info (collapsed by default)
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

// MARK: - Supporting Views

/// displays the app icon from the asset catalog
struct AppIconView: View {
    var body: some View {
        // try to load app icon from bundle
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let iconName = iconFiles.last,
           let uiImage = UIImage(named: iconName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // fallback: generic music icon
            Image(systemName: "music.note.house.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(AppColor.color1)
                .padding(16)
                .background(AppColor.color1.opacity(0.1))
        }
    }
}

/// a row showing a credit (role and name)
struct CreditRow: View {
    let role: String
    let name: String

    var body: some View {
        HStack {
            Text(role)
                .foregroundStyle(.secondary)
            Spacer()
            Text(name)
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
    .environment(SyncManager.shared)
}
