//
//  BarAppearance.swift
//  Coulisse
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

import AppKit

// MARK: - Icon spacing

/// The space macOS leaves between menu bar icons. A system setting for every app
/// (NSStatusItemSpacing and NSStatusItemSelectionPadding in the global domain of
/// this Mac); macOS applies it when each app with an icon starts again.
enum IconSpacing: String, CaseIterable {
    case normal
    case compact
    case tighter

    /// nil: macOS's own spacing (the keys are removed).
    var values: (spacing: Int, padding: Int)? {
        switch self {
        case .normal: return nil
        case .compact: return (8, 8)
        case .tighter: return (4, 6)
        }
    }

    var titleKey: String {
        switch self {
        case .normal: return "Normal"
        case .compact: return "Compact"
        case .tighter: return "Tighter"
        }
    }

    /// The choice the stored values match; values set by hand read as normal.
    static func matching(spacing: Int?, padding: Int?) -> IconSpacing {
        allCases.first { choice in
            guard let values = choice.values else { return spacing == nil && padding == nil }
            return values.spacing == spacing && values.padding == padding
        } ?? .normal
    }
}

enum SystemIconSpacing {
    static let spacingKey = "NSStatusItemSpacing"
    static let paddingKey = "NSStatusItemSelectionPadding"

    private static func read(_ key: String) -> Int? {
        (CFPreferencesCopyValue(key as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser,
                                kCFPreferencesCurrentHost) as? NSNumber)?.intValue
    }

    private static func write(_ key: String, _ value: Int?) {
        CFPreferencesSetValue(key as CFString, value.map { NSNumber(value: $0) }, kCFPreferencesAnyApplication,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    static var current: IconSpacing {
        IconSpacing.matching(spacing: read(spacingKey), padding: read(paddingKey))
    }

    static func apply(_ choice: IconSpacing) {
        write(spacingKey, choice.values?.spacing)
        write(paddingKey, choice.values?.padding)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }
}

// MARK: - Tint

/// A color drawn behind the menu bar, from a stored "#RRGGBB" string.
enum MenuBarTintColor {
    static let defaultHex = "#5B21B6"

    static func color(hex: String?) -> NSColor {
        let digits = (hex ?? defaultHex).trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return color(hex: defaultHex) }
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255,
                       blue: CGFloat(value & 0xff) / 255, alpha: 1)
    }

    static func hex(of color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return defaultHex }
        func byte(_ c: CGFloat) -> Int { Int((min(max(c, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(rgb.redComponent), byte(rgb.greenComponent), byte(rgb.blueComponent))
    }

    /// The strip of a screen the menu bar covers, nil when it is hidden there.
    static func band(frame: CGRect, visibleFrame: CGRect) -> CGRect? {
        let height = frame.maxY - visibleFrame.maxY
        guard height > 1 else { return nil }
        return CGRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height)
    }
}
