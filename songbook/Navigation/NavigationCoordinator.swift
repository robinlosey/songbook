//
//  NavigationCoordinator.swift
//  songbook
//
//  Shared navigation state for both iPhone and iPad platforms.
//  Uses @Observable (iOS 17+) for modern, efficient observation.
//

import SwiftUI
import CoreData

@Observable
class NavigationCoordinator {
    // selected category (nil = All Songs)
    var selectedCategory: Category?

    // selected song for viewing
    var selectedSong: Song?

    // navigation stack path for iPhone
    var navigationPath = NavigationPath()

    // MARK: - Navigation Actions

    func selectCategory(_ category: Category?) {
        selectedCategory = category
        selectedSong = nil
    }

    func selectSong(_ song: Song) {
        selectedSong = song
    }

    func clearSong() {
        selectedSong = nil
    }

    func reset() {
        selectedCategory = nil
        selectedSong = nil
        navigationPath = NavigationPath()
    }

    // MARK: - Convenience

    var categoryTitle: String {
        selectedCategory?.name ?? "All Songs"
    }
}
