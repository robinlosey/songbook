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
                        SettingsRow(
                            icon: "gear",
                            iconColor: AppColor.color1,
                            title: "General"
                        )
                    }

                    NavigationLink {
                        DownloadSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "arrow.down.circle.fill",
                            iconColor: AppColor.color2,
                            title: "Downloads"
                        )
                    }

                    NavigationLink {
                        StorageView()
                    } label: {
                        SettingsRow(
                            icon: "internaldrive.fill",
                            iconColor: AppColor.color3,
                            title: "Storage"
                        )
                    }
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsRow(
                            icon: "info.circle.fill",
                            iconColor: AppColor.color4,
                            title: "About"
                        )
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(AppColor.accent)
                }
            }
        }
        .presentationDetents(sizeClass == .regular ? [.medium, .large] : [.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(colorScheme)
    }
}

// MARK: - Settings Row

/// styled settings row with colored icon
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(iconColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(title)
        }
    }
}

#Preview {
    SettingsView()
        .environment(SyncManager.shared)
}
