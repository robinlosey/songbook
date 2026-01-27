//
//  CategoryRowView.swift
//  songbook
//
//  Extracted from CategoryListView - reusable category row component.
//

import SwiftUI

struct CategoryRowView: View {
    let name: String?
    let count: Int?  // nil means loading
    var isAllSongs: Bool = false

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name ?? "Unknown Category")
                    .font(AppFont.headline)

                if let count = count {
                    Text("\(count) \(count == 1 ? "song" : "songs")")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // loading indicator
            if count == nil {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.vertical, AppSpacing.small)
    }
}

#Preview("With Count") {
    List {
        CategoryRowView(name: "All Songs", count: 142, isAllSongs: true)
        CategoryRowView(name: "Hymns", count: 42)
        CategoryRowView(name: "Christmas Songs", count: 15)
        CategoryRowView(name: "Solo Track", count: 1)
    }
}

#Preview("Loading") {
    List {
        CategoryRowView(name: "All Songs", count: nil, isAllSongs: true)
    }
}
