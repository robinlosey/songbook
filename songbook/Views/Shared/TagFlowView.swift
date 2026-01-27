//
//  TagFlowView.swift
//  songbook
//
//  A view that displays category tags in a wrapping flow layout.
//

import SwiftUI

struct TagFlowView: View {
    let tags: [Category]
    let maxVisible: Int
    
    // Using a subtle accent color background (secondary accent)
    private let tagBackgroundColor = AppColor.color2.opacity(0.15)
    
    init(tags: [Category], maxVisible: Int = 3) {
        self.tags = tags
        self.maxVisible = maxVisible
    }

    var body: some View {
        let visibleTags = Array(tags.prefix(maxVisible))
        let overflow = tags.count - maxVisible

        HStack(spacing: 4) {
            ForEach(visibleTags) { tag in
                Text(tag.name ?? "")
                    .font(AppFont.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(LinearGradient(
                                colors: [tagBackgroundColor, tagBackgroundColor.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                    }
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .shadow(color: tagBackgroundColor.opacity(0.3), radius: 2, x: 0, y: 1)
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
        }
    }
}

#Preview {
    // Mock data for preview
    let context = DataManager.preview.container.viewContext
    let cat1 = Category(context: context)
    cat1.name = "Hymns"
    let cat2 = Category(context: context)
    cat2.name = "Favorites"
    let cat3 = Category(context: context)
    cat3.name = "Christmas"
    let cat4 = Category(context: context)
    cat4.name = "Youth"

    return VStack(alignment: .leading, spacing: 20) {
        TagFlowView(tags: [cat1, cat2])
        TagFlowView(tags: [cat1, cat2, cat3, cat4])
    }
    .padding()
}
