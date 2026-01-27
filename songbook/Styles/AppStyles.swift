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

// MARK: - Color Palette

/// theme colors derived from the app icon (stained glass hibiscus & hummingbird)
enum AppColor {
    // primary accent (main brand color)
    static let accent = Color.accentColor

    // palette inspired by icon - hummingbird teal, indigo wing, soft rose, forest green, crimson flower
    static let color1 = Color("AccentColor_2") // hummingbird teal - primary accent
    static let color2 = Color("AccentColor_4") // deep indigo - secondary/buttons
    static let color3 = Color("AccentColor_3") // soft rose - backgrounds/warmth
    static let color4 = Color("AccentColor_5") // forest green - tertiary/tags
    static let color5 = Color("AccentColor")   // deep crimson - destructive only

    // semantic aliases for clarity
    static let primary = color1
    static let secondary = color2
    static let warmAccent = color3
    static let tertiary = color4
    static let destructive = color5

    // convenience array for indexed access (excludes destructive)
    static let palette: [Color] = [color1, color2, color3, color4]

    // helper to get consistent color for a string (like category name)
    static func forString(_ string: String) -> Color {
        let hash = abs(string.hashValue)
        return palette[hash % palette.count]
    }
}

// MARK: - App Backgrounds

struct MeshBackground: View {
    @State private var appear = false

    var body: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [appear ? 0.55 : 0.45, appear ? 0.45 : 0.55], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    // soft rose and teal dominate - warm, elegant feel
                    AppColor.warmAccent.opacity(0.15), AppColor.primary.opacity(0.08), AppColor.warmAccent.opacity(0.12),
                    AppColor.primary.opacity(0.06), AppColor.warmAccent.opacity(0.10), AppColor.secondary.opacity(0.06),
                    AppColor.warmAccent.opacity(0.12), AppColor.tertiary.opacity(0.05), AppColor.warmAccent.opacity(0.15)
                ]
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 12.0).repeatForever(autoreverses: true)) {
                    appear = true
                }
            }
            .blur(radius: 50)
        } else {
            // elegant fallback: soft rose gradient reminiscent of icon's flowing background
            ZStack {
                LinearGradient(
                    colors: [
                        AppColor.warmAccent.opacity(0.12),
                        AppColor.warmAccent.opacity(0.06),
                        AppColor.primary.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // subtle radial accent in corner
                RadialGradient(
                    colors: [AppColor.primary.opacity(0.08), .clear],
                    center: .bottomTrailing,
                    startRadius: 50,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()
        }
    }
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
