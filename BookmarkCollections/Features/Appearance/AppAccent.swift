import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Curated accent palette. Each accent stores a {dark, light} pair pre-tuned
/// so the resolved color always clears contrast against the current theme —
/// text stays neutral; only icons, counts, and selection chrome take the tint.
enum AppAccent: String, CaseIterable, Identifiable {
    case grape
    case coral
    case amber
    case cherry
    case fern
    case teal
    case graphite

    static let storageKey = "accentKey"
    static let defaultAccent: AppAccent = .grape

    init(storedKey: String) {
        self = AppAccent(rawValue: storedKey) ?? Self.defaultAccent
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grape: "Grape"
        case .coral: "Coral"
        case .amber: "Amber"
        case .cherry: "Cherry"
        case .fern: "Fern"
        case .teal: "Teal"
        case .graphite: "Graphite"
        }
    }

    /// Resolves to the dark-tuned value in dark mode and the light-tuned
    /// value in light mode, tracking system appearance changes automatically.
    var color: Color {
        let pair = hexPair
        #if os(macOS)
        return Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Self.color(hex: isDark ? pair.dark : pair.light))
        })
        #else
        return Color(UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return UIColor(Self.color(hex: isDark ? pair.dark : pair.light))
        })
        #endif
    }

    private var hexPair: (dark: UInt32, light: UInt32) {
        switch self {
        case .grape: (0xB388FF, 0x8A4FE0)
        case .coral: (0xF0865F, 0xD1613A)
        case .amber: (0xFFB340, 0xB7791F)
        case .cherry: (0xFF6961, 0xD70015)
        case .fern: (0x5BE37D, 0x1A9D4D)
        case .teal: (0x5AC8FA, 0x0A84C4)
        case .graphite: (0xC7C7CC, 0x636366)
        }
    }

    private static func color(hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
