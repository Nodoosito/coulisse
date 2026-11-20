//
//  SettingsBackupTests.swift
//  HiddenTests
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

import XCTest
@testable import Coulisse

#if HIDDENBAR_NATIVE_VISIBILITY

/// Contract: a settings file carries every known setting with its type, plus the
/// profiles and rules; importing one replaces those settings and nothing else; a
/// file without the version marker or with wrong types is refused or filtered.
/// Serves: SettingsBackup. Mock boundary: two throwaway defaults suites.
final class SettingsBackupTests: XCTestCase {
    private var suites: [String] = []

    private func makeDefaults() -> UserDefaults {
        let name = "SettingsBackupTests.\(UUID().uuidString)"
        suites.append(name)
        return UserDefaults(suiteName: name)!
    }

    override func tearDown() {
        suites.forEach { UserDefaults().removePersistentDomain(forName: $0) }
        super.tearDown()
    }

    func test_roundTrip_carriesSettingsProfilesAndRules() throws {
        let source = makeDefaults()
        source.set(true, forKey: UserDefaults.Key.isAutoHide)
        source.set(120.0, forKey: UserDefaults.Key.numberOfSecondForAutoHide)
        source.set("window", forKey: UserDefaults.Key.arrowClickMode)
        source.set(Data([1, 2, 3]), forKey: AppRuleStore.key)
        source.set("unrelated", forKey: "someOtherKey")
        let file = try SettingsBackup.data(from: source)

        let target = makeDefaults()
        target.set("expand", forKey: UserDefaults.Key.arrowClickMode)
        target.set(true, forKey: UserDefaults.Key.hoverToExpand)
        target.set("keep me", forKey: "someOtherKey")
        let values = try XCTUnwrap(SettingsBackup.values(in: file).flatMap(SettingsBackup.importable))
        SettingsBackup.apply(values, to: target)

        XCTAssertTrue(target.bool(forKey: UserDefaults.Key.isAutoHide))
        XCTAssertEqual(target.double(forKey: UserDefaults.Key.numberOfSecondForAutoHide), 120)
        XCTAssertEqual(target.string(forKey: UserDefaults.Key.arrowClickMode), "window")
        XCTAssertEqual(target.data(forKey: AppRuleStore.key), Data([1, 2, 3]))
        XCTAssertNil(target.object(forKey: UserDefaults.Key.hoverToExpand), "a setting the file lacks goes back to its default")
        XCTAssertEqual(target.string(forKey: "someOtherKey"), "keep me", "unknown keys are never touched")
    }

    func test_refusesOtherFilesAndWrongTypes() {
        XCTAssertNil(SettingsBackup.importable(["arrowClickMode": "window"]), "no version marker")
        let filtered = SettingsBackup.importable([SettingsBackup.versionKey: 1, "arrowClickMode": 3, "isAutoHide": true, "evil": "x"])
        XCTAssertEqual(filtered?.keys.sorted(), ["isAutoHide"])
    }
}

#endif
