//
//  IconProfileModel.swift
//  Coulisse
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

import Foundation

/// What switches a profile on by itself.
enum IconProfileTrigger: String, Codable, CaseIterable {
    case manual
    /// Any external display, or the one named in the rule.
    case externalDisplay
    case noExternalDisplay
    case onBattery
    case onPower
}

struct IconProfileRule: Codable, Equatable {
    var trigger: IconProfileTrigger
    /// For `externalDisplay`: the display's name as macOS gives it; nil for any.
    var displayName: String?

    static let manual = IconProfileRule(trigger: .manual, displayName: nil)
}

/// One saved layout: the section of every app, and when it applies.
struct IconProfile: Codable, Equatable {
    var id: String
    var name: String
    var rule: IconProfileRule
    /// Bundle id to `MenuBarSection` raw value, the pinned-sections table's shape.
    var sections: [String: Int]
}

/// What the Mac looks like right now, as far as rules care.
struct IconProfileContext: Equatable {
    /// Names of the external (not built-in) displays connected.
    var externalDisplays: [String]
    var onBattery: Bool
}

/// Picks the profile a context asks for. Pure, so the rules are tested without hardware.
enum IconProfileResolver {
    /// How well `rule` fits `context`: 0 does not apply; a named display beats any
    /// display, which beats power and the absence of a display.
    static func score(_ rule: IconProfileRule, in context: IconProfileContext) -> Int {
        switch rule.trigger {
        case .manual:
            return 0
        case .externalDisplay:
            guard !context.externalDisplays.isEmpty else { return 0 }
            guard let name = rule.displayName else { return 2 }
            return context.externalDisplays.contains(name) ? 3 : 0
        case .noExternalDisplay:
            return context.externalDisplays.isEmpty ? 1 : 0
        case .onBattery:
            return context.onBattery ? 1 : 0
        case .onPower:
            return context.onBattery ? 0 : 1
        }
    }

    /// The automatic profile that fits best (the first one listed on a tie), else
    /// the base profile: the one picked by hand last, else the first.
    static func profile(for context: IconProfileContext, in profiles: [IconProfile], baseID: String?) -> IconProfile? {
        var best: (profile: IconProfile, score: Int)?
        for profile in profiles {
            let score = score(profile.rule, in: context)
            if score > 0, score > (best?.score ?? 0) { best = (profile, score) }
        }
        if let best { return best.profile }
        return profiles.first { $0.id == baseID } ?? profiles.first
    }

    /// A name not used yet: "Profile 2", "Profile 3"...
    static func newName(format: String, existing: [String]) -> String {
        var number = existing.count + 1
        while existing.contains(String(format: format, number)) { number += 1 }
        return String(format: format, number)
    }
}

/// The saved profiles, the active one and the base one, in a defaults domain.
struct IconProfileStore {
    static let profilesKey = "iconProfiles"
    static let activeKey = "iconProfileActive"
    static let baseKey = "iconProfileBase"

    let defaults: UserDefaults

    var profiles: [IconProfile] {
        get {
            guard let data = defaults.data(forKey: Self.profilesKey),
                  let decoded = try? JSONDecoder().decode([IconProfile].self, from: data) else { return [] }
            return decoded
        }
        nonmutating set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: Self.profilesKey)
            } else if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Self.profilesKey)
            }
        }
    }

    var activeID: String? {
        get { defaults.string(forKey: Self.activeKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.activeKey) }
    }

    var baseID: String? {
        get { defaults.string(forKey: Self.baseKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.baseKey) }
    }
}
