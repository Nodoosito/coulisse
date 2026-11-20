//
//  AppRuleTests.swift
//  HiddenTests
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

import XCTest
import AppKit
@testable import Coulisse

/// Contract: a rule shows its icon only while its front app is active; rules are
/// saved, changed and removed; the manager tells its listener only when the shown
/// set changes. Serves: AppRuleResolver, AppRuleStore, AppRuleManager.
/// Mock boundary: a throwaway defaults suite, a private workspace center and a
/// front app set by the test.
final class AppRuleTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private var front: String?
    private var workspace: NotificationCenter!
    private var manager: AppRuleManager!
    private var changes = 0

    override func setUp() {
        super.setUp()
        suite = "AppRuleTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        workspace = NotificationCenter()
        manager = AppRuleManager(store: AppRuleStore(defaults: defaults), frontApp: { [unowned self] in front }, workspace: workspace)
        manager.onChange = { [unowned self] in changes += 1 }
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func test_resolver_showsOnlyWhileTheFrontAppIsActive() {
        let rules = [AppRule(id: "1", bundle: "com.docker", frontApp: "com.vscode"),
                     AppRule(id: "2", bundle: "com.paste", frontApp: "com.paste")]
        XCTAssertEqual(AppRuleResolver.shown(by: rules, front: "com.vscode"), ["com.docker"])
        XCTAssertEqual(AppRuleResolver.shown(by: rules, front: "com.paste"), ["com.paste"])
        XCTAssertEqual(AppRuleResolver.shown(by: rules, front: "com.safari"), [])
        XCTAssertEqual(AppRuleResolver.shown(by: rules, front: nil), [])
    }

    func test_manager_followsTheFrontAppAndSavesRules() {
        manager.start()
        manager.add(bundle: "com.docker", frontApp: "com.vscode")
        XCTAssertEqual(manager.rules.count, 1)
        XCTAssertEqual(manager.shownNow, [])
        front = "com.vscode"
        workspace.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
        XCTAssertEqual(manager.shownNow, ["com.docker"])
        XCTAssertEqual(changes, 1)
        workspace.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
        XCTAssertEqual(changes, 1, "the same front app changes nothing")
        let id = manager.rules[0].id
        manager.update(id, frontApp: "com.docker")
        XCTAssertEqual(manager.shownNow, [], "the rule now follows Docker itself")
        manager.remove(id)
        XCTAssertTrue(manager.rules.isEmpty)
        XCTAssertNil(defaults.data(forKey: AppRuleStore.key))
    }

    func test_add_defaultsToTheAppItself() {
        manager.add(bundle: "com.paste")
        XCTAssertEqual(manager.rules.first?.frontApp, "com.paste")
    }
}
