//
//  IconProfileTests.swift
//  HiddenTests
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

import XCTest
import AppKit
@testable import Coulisse

/// Contract: the profile whose rule fits the Mac best is picked (a named display
/// beats any display, which beats power), else the one chosen by hand last;
/// switching saves the bar into the profile left and puts the new one in place;
/// edits to the sections go to the active profile; fewer than two profiles turn
/// the feature off.
/// Serves: IconProfileResolver, IconProfileStore, IconProfileManager.
/// Mock boundary: a throwaway defaults suite, an in-memory pinned table, a
/// private notification center and a context set by the test. No display or
/// power source is read.
final class IconProfileResolverTests: XCTestCase {

    private func profile(_ id: String, _ trigger: IconProfileTrigger, display: String? = nil) -> IconProfile {
        IconProfile(id: id, name: id, rule: IconProfileRule(trigger: trigger, displayName: display), sections: [:])
    }

    func test_namedDisplayBeatsAnyDisplayBeatsPower() {
        let profiles = [profile("home", .manual), profile("power", .onPower), profile("any", .externalDisplay),
                        profile("office", .externalDisplay, display: "DELL U2720Q")]
        let office = IconProfileContext(externalDisplays: ["DELL U2720Q"], onBattery: false)
        XCTAssertEqual(IconProfileResolver.profile(for: office, in: profiles, baseID: "home")?.id, "office")
        let other = IconProfileContext(externalDisplays: ["LG"], onBattery: false)
        XCTAssertEqual(IconProfileResolver.profile(for: other, in: profiles, baseID: "home")?.id, "any")
        let alone = IconProfileContext(externalDisplays: [], onBattery: false)
        XCTAssertEqual(IconProfileResolver.profile(for: alone, in: profiles, baseID: "home")?.id, "power")
    }

    func test_noRuleFits_fallsBackToTheBaseThenTheFirst() {
        let profiles = [profile("a", .manual), profile("b", .manual), profile("battery", .onBattery)]
        let plugged = IconProfileContext(externalDisplays: [], onBattery: false)
        XCTAssertEqual(IconProfileResolver.profile(for: plugged, in: profiles, baseID: "b")?.id, "b")
        XCTAssertEqual(IconProfileResolver.profile(for: plugged, in: profiles, baseID: "gone")?.id, "a")
        let battery = IconProfileContext(externalDisplays: [], onBattery: true)
        XCTAssertEqual(IconProfileResolver.profile(for: battery, in: profiles, baseID: "b")?.id, "battery")
    }

    func test_noExternalDisplayRule() {
        let rule = IconProfileRule(trigger: .noExternalDisplay)
        XCTAssertEqual(IconProfileResolver.score(rule, in: IconProfileContext(externalDisplays: [], onBattery: true)), 1)
        XCTAssertEqual(IconProfileResolver.score(rule, in: IconProfileContext(externalDisplays: ["LG"], onBattery: true)), 0)
    }

    func test_newNameSkipsTakenOnes() {
        XCTAssertEqual(IconProfileResolver.newName(format: "Profile %d", existing: ["Default"]), "Profile 2")
        XCTAssertEqual(IconProfileResolver.newName(format: "Profile %d", existing: ["Default", "Profile 3", "x"]), "Profile 4")
    }
}

#if HIDDENBAR_NATIVE_VISIBILITY

final class IconProfileManagerTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private var table: InMemorySectionMemory!
    private var center: NotificationCenter!
    private var context = IconProfileContext(externalDisplays: [], onBattery: false)
    private var manager: IconProfileManager!

    override func setUp() {
        super.setUp()
        suite = "IconProfileManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        table = InMemorySectionMemory()
        table.sections = ["com.paste": .hidden, "com.zoom": .visible]
        center = NotificationCenter()
        manager = IconProfileManager(store: IconProfileStore(defaults: defaults), table: table, center: center,
                                     context: { [unowned self] in context })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func id(_ index: Int) -> String { manager.profiles[index].id }

    func test_createInitialProfiles_copiesTheBarIntoTwoProfiles() {
        XCTAssertFalse(manager.isOn)
        manager.createInitialProfiles()
        XCTAssertTrue(manager.isOn)
        XCTAssertEqual(manager.profiles.count, 2)
        XCTAssertEqual(manager.activeID, id(0))
        XCTAssertEqual(manager.profiles[1].sections, ["com.paste": MenuBarSection.hidden.rawValue, "com.zoom": MenuBarSection.visible.rawValue])
    }

    // Given two profiles and an edit to the bar
    // When the user switches profile and back
    // Then each profile keeps its own layout
    func test_switching_keepsEachProfilesLayout() {
        manager.start()
        manager.createInitialProfiles()
        manager.choose(id(1))
        table.sections["com.paste"] = .visible
        center.post(name: .pinnedSectionsChanged, object: nil)
        XCTAssertEqual(manager.active?.sections["com.paste"], MenuBarSection.visible.rawValue, "an edit goes to the active profile")
        manager.choose(id(0))
        XCTAssertEqual(table.sections["com.paste"], .hidden, "the first profile comes back as it was")
        manager.choose(id(1))
        XCTAssertEqual(table.sections["com.paste"], .visible)
    }

    // Given a profile for an external display
    // When the display is connected, then removed
    // Then that profile turns on by itself, then the one picked by hand comes back
    func test_rule_switchesWithTheContext() {
        manager.start()
        manager.createInitialProfiles()
        manager.setRule(id(1), IconProfileRule(trigger: .externalDisplay, displayName: "DELL"))
        XCTAssertEqual(manager.activeID, id(0))
        context = IconProfileContext(externalDisplays: ["DELL"], onBattery: false)
        manager.contextMayHaveChanged()
        XCTAssertEqual(manager.activeID, id(1))
        context = IconProfileContext(externalDisplays: [], onBattery: false)
        manager.contextMayHaveChanged()
        XCTAssertEqual(manager.activeID, id(0))
    }

    func test_removingDownToOne_turnsProfilesOff() {
        manager.createInitialProfiles()
        manager.remove(id(1))
        XCTAssertFalse(manager.isOn)
        XCTAssertTrue(manager.profiles.isEmpty)
        XCTAssertNil(manager.activeID)
        XCTAssertEqual(table.sections["com.paste"], .hidden, "the bar keeps its layout")
    }

    func test_renameIgnoresBlankNames() {
        manager.createInitialProfiles()
        manager.rename(id(1), to: "  Bureau ")
        XCTAssertEqual(manager.profiles[1].name, "Bureau")
        manager.rename(id(1), to: "   ")
        XCTAssertEqual(manager.profiles[1].name, "Bureau")
    }
}

#endif
