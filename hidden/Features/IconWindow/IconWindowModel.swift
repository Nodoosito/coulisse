//
//  IconWindowModel.swift
//  Coulisse
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

import Foundation

/// One app in the icon window.
struct IconWindowTile: Equatable {
    let bundleIdentifier: String
    let name: String
    let section: MenuBarSection
}

/// What the icon window shows.
enum IconWindowContent: Equatable {
    case tiles(hidden: [IconWindowTile], alwaysHidden: [IconWindowTile])
    case nothingHidden
    case accessibilityOff
    case engineUnavailable
    /// Typed letters that match no hidden app.
    case noMatch(String)

    var tileCount: Int {
        guard case .tiles(let hidden, let alwaysHidden) = self else { return 0 }
        return hidden.count + alwaysHidden.count
    }
}

/// The icon window's rules, free of AppKit so they are tested without a window.
/// It lists the same apps the palette finds: hidden or always hidden, running,
/// and not kept out of sight by presentation mode.
enum IconWindowModel {
    static let maxColumns = 6

    /// `query`: letters typed into the window; the tiles keep the palette's ranking.
    static func content(candidates: [PaletteCandidate], environment: PaletteEnvironment, query: String = "") -> IconWindowContent {
        // The permission comes first: without it nothing can be read or pressed.
        guard environment.accessibilityTrusted else { return .accessibilityOff }
        guard environment.engineAvailable else { return .engineUnavailable }
        let shown = candidates.filter { $0.isFindable && !environment.hiddenWhilePresenting.contains($0.bundleIdentifier) }
        guard !shown.isEmpty else { return .nothingHidden }
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty {
            let matches = PaletteRanking.rank(query: typed, in: shown).map(\.candidate)
            guard !matches.isEmpty else { return .noMatch(typed) }
            func ranked(_ section: MenuBarSection) -> [IconWindowTile] {
                matches.filter { $0.section == section }
                    .map { IconWindowTile(bundleIdentifier: $0.bundleIdentifier, name: $0.name, section: $0.section) }
            }
            return .tiles(hidden: ranked(.hidden), alwaysHidden: ranked(.alwaysHidden))
        }
        func tiles(_ section: MenuBarSection) -> [IconWindowTile] {
            shown.filter { $0.section == section }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .map { IconWindowTile(bundleIdentifier: $0.bundleIdentifier, name: $0.name, section: $0.section) }
        }
        return .tiles(hidden: tiles(.hidden), alwaysHidden: tiles(.alwaysHidden))
    }

    /// Rows of at most `columns` items, in order.
    static func rows<T>(_ items: [T], columns: Int = maxColumns) -> [[T]] {
        guard columns > 0 else { return [items] }
        return stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
    }

    /// How many columns the grid uses: as many as the longest section needs, up to the maximum.
    /// The tiles in the order the window draws them.
    static func orderedTiles(_ content: IconWindowContent) -> [IconWindowTile] {
        guard case .tiles(let hidden, let alwaysHidden) = content else { return [] }
        return hidden + alwaysHidden
    }

    /// The text a key press adds to the query, nil when the key is not for typing.
    static func typedText(characters: String?, commandOrControl: Bool) -> String? {
        guard !commandOrControl, let characters, !characters.isEmpty,
              characters.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(.punctuationCharacters).union([" "]).contains($0) })
        else { return nil }
        return characters
    }

    static func columns(for content: IconWindowContent) -> Int {
        guard case .tiles(let hidden, let alwaysHidden) = content else { return maxColumns }
        return max(1, min(maxColumns, max(hidden.count, alwaysHidden.count)))
    }
}

/// When a click on the arrow opens the icon window instead of expanding the bar.
enum IconWindowPolicy {
    /// `barOverflows`: macOS shows its « button now, or the last expand did not fit.
    static func opensWindow(mode: ArrowClickMode, isCollapsed: Bool, usesNativeEngine: Bool, barOverflows: Bool) -> Bool {
        guard usesNativeEngine, isCollapsed else { return false }
        switch mode {
        case .expand: return false
        case .window: return true
        case .automatic: return barOverflows
        }
    }

    /// Automatic mode needs to ask macOS about its « button before it decides.
    static func needsOverflowRead(mode: ArrowClickMode, isCollapsed: Bool, usesNativeEngine: Bool, remembersOverflow: Bool) -> Bool {
        usesNativeEngine && isCollapsed && mode == .automatic && !remembersOverflow
    }

    /// An expand the arrow click asked for put icons into «: in automatic mode the
    /// bar folds back and the icons open in the window instead.
    static func foldsIntoWindow(mode: ArrowClickMode, fromArrowClick: Bool, movedIntoOverflow: Set<String>) -> Bool {
        mode == .automatic && fromArrowClick && !movedIntoOverflow.isEmpty
    }
}

/// Whether the last expand overflowed. Automatic mode then opens the window
/// without asking macOS again, until the displays change or an expand fits.
struct IconWindowOverflowMemory: Equatable {
    private(set) var overflowed = false

    mutating func recordExpand(movedIntoOverflow: Set<String>) {
        overflowed = !movedIntoOverflow.isEmpty
    }

    mutating func displaysChanged() {
        overflowed = false
    }
}
