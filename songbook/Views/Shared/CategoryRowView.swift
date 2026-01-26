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

    var body: some View {
        HStack {
            Text(name ?? "Unknown Category")
                .font(.headline)
            Spacer()
            if let count = count {
                Text("\(count) Songs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // spinner while count loads
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 20, height: 20)
            }
        }
        .padding()
    }
}

#Preview("With Count") {
    List {
        CategoryRowView(name: "Hymns", count: 42)
        CategoryRowView(name: "Christmas Songs", count: 15)
    }
}

#Preview("Loading") {
    List {
        CategoryRowView(name: "All Songs", count: nil)
    }
}
