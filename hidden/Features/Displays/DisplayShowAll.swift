//
//  DisplayShowAll.swift
//  Coulisse
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

import AppKit

/// When Coulisse keeps every icon shown because a display has room for them.
/// macOS hides an icon on every display at once, so this is all or nothing.
enum DisplayShowAllMode: String, CaseIterable {
    case never
    /// Any external display is connected.
    case externalConnected
    /// Only external displays are in use: a laptop closed on a monitor.
    case externalOnly

    static let `default`: DisplayShowAllMode = .never

    init(storedValue: String?) {
        self = storedValue.flatMap(DisplayShowAllMode.init(rawValue:)) ?? .default
    }
}

/// How many built-in and external displays are in use.
struct DisplayCounts: Equatable {
    var builtIn: Int
    var external: Int

    static func live() -> DisplayCounts {
        var counts = DisplayCounts(builtIn: 0, external: 0)
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            if CGDisplayIsBuiltin(number.uint32Value) != 0 { counts.builtIn += 1 } else { counts.external += 1 }
        }
        return counts
    }
}

enum DisplayShowAllPolicy {
    static func showsAll(_ mode: DisplayShowAllMode, displays: DisplayCounts) -> Bool {
        switch mode {
        case .never: return false
        case .externalConnected: return displays.external > 0
        case .externalOnly: return displays.external > 0 && displays.builtIn == 0
        }
    }

    /// What to do with the bar: expand it for the displays, give it back, or nothing.
    enum Step: Equatable { case expand, collapse, none }

    /// `expandedForDisplays`: Coulisse expanded the bar for the displays and still holds it.
    static func step(showsAll: Bool, isCollapsed: Bool, expandedForDisplays: Bool) -> Step {
        if showsAll { return isCollapsed && !expandedForDisplays ? .expand : .none }
        return expandedForDisplays ? .collapse : .none
    }
}
