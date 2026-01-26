//
//  AppStyles.swift
//  songbook
//
//  Central location for typography and spacing customization.
//  Developers can rebrand by changing values here.
//

import SwiftUI

// MARK: - Typography

/// customizable font design - change this to rebrand typography
enum AppFont {
    // change .default to .serif or .rounded to rebrand
    static let design: Font.Design = .default

    static var largeTitle: Font { .system(.largeTitle, design: design) }
    static var title: Font { .system(.title, design: design) }
    static var title2: Font { .system(.title2, design: design) }
    static var title3: Font { .system(.title3, design: design) }
    static var headline: Font { .system(.headline, design: design) }
    static var subheadline: Font { .system(.subheadline, design: design) }
    static var body: Font { .system(.body, design: design) }
    static var callout: Font { .system(.callout, design: design) }
    static var caption: Font { .system(.caption, design: design) }
    static var caption2: Font { .system(.caption2, design: design) }
    static var footnote: Font { .system(.footnote, design: design) }
}

// MARK: - Spacing

/// consistent spacing values throughout the app
enum AppSpacing {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 24

    static let listRowPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let componentSpacing: CGFloat = 8
}

// MARK: - Corner Radii

enum AppCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 20
}

// MARK: - Animation

enum AppAnimation {
    static let standard = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let quick = Animation.easeInOut(duration: 0.2)
    static let slow = Animation.easeInOut(duration: 0.4)
}

// MARK: - Adaptive Glass Modifier (iOS 26 Ready)

struct AdaptiveGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        // TODO: when iOS 26 ships, add .glassEffect(.regular) branch
        content.background(.thinMaterial)
    }
}

extension View {
    func adaptiveGlass() -> some View {
        modifier(AdaptiveGlassModifier())
    }
}
