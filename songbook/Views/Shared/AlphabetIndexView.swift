//
//  AlphabetIndexView.swift
//  songbook
//
//  Extracted from SongListView - A-Z quick scroll index with magnification effect.
//

import SwiftUI

struct AlphabetIndexView: View {
    let keys: [String]
    let proxy: ScrollViewProxy
    @State private var activeKeyIndex: Int?
    private let rowHeight: CGFloat = 22

    private func scrollTo(keyIndex: Int) {
        if keyIndex >= 0 && keyIndex < keys.count {
            let key = keys[keyIndex]
            if activeKeyIndex != keyIndex {
                proxy.scrollTo(key, anchor: .top)
                activeKeyIndex = keyIndex
            }
        }
    }

    // fisheye-style magnification for nearby letters
    private func magnificationEffect(for index: Int) -> (scale: CGFloat, offset: CGFloat) {
        guard let activeKeyIndex = activeKeyIndex else {
            return (1.0, 0)
        }
        let distance = abs(index - activeKeyIndex)

        switch distance {
        case 0:
            return (1.8, -25)  // active letter: largest scale
        case 1:
            return (1.5, -15)  // immediate neighbors
        case 2:
            return (1.2, -5)   // two away
        default:
            return (1.0, 0)    // no effect
        }
    }

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 0) {
                ForEach(Array(keys.enumerated()), id: \.element) { index, key in
                    let (scale, offset) = magnificationEffect(for: index)

                    Text(key)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.accent)
                        .frame(width: 30, height: rowHeight)
                        .contentShape(Rectangle())
                        .scaleEffect(scale)
                        .offset(x: offset)
                        .zIndex(scale > 1.0 ? 1 : 0)
                }
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: activeKeyIndex)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let y = value.location.y
                        let index = Int(y / rowHeight)
                        let clampedIndex = max(0, min(keys.count - 1, index))

                        scrollTo(keyIndex: clampedIndex)
                    }
                    .onEnded { _ in
                        activeKeyIndex = nil
                    }
            )
            .padding(.trailing, 2)
        }
    }
}

#Preview {
    ScrollViewReader { proxy in
        List {
            ForEach(["A", "B", "C", "D", "E"], id: \.self) { key in
                Section(header: Text(key)) {
                    Text("Item in \(key)")
                }
                .id(key)
            }
        }
        .overlay(
            AlphabetIndexView(keys: ["A", "B", "C", "D", "E"], proxy: proxy)
        )
    }
}
