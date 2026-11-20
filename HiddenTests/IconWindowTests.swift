//
//  IconWindowTests.swift
//  HiddenTests
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

import XCTest
import AppKit
@testable import Coulisse

/// Contract: the icon window lists the running hidden and always-hidden apps by
/// name, opens when the arrow click mode says so, folds an overflowing expand
/// into itself in automatic mode, opens an app on a tile click, says why when
/// macOS found no room, and stays closed for the click that closed it.
/// Serves: IconWindowModel, IconWindowPolicy, IconWindowOverflowMemory,
/// ArrowClickMode, IconWindowController.
/// Mock boundary: candidates and environments built by hand; for the controller
/// a fixture catalog (throwaway defaults suite, private notification center,
/// fixture resolver), a fake host and a fake clock. The panel is never ordered
/// onto the screen.
final class IconWindowModelTests: XCTestCase {

    private func app(_ name: String, _ section: MenuBarSection, running: Bool = true) -> PaletteCandidate {
        PaletteCandidate(bundleIdentifier: "com.\(name.lowercased())", name: name, section: section, isRunning: running)
    }

    private let ready = PaletteEnvironment(accessibilityTrusted: true, engineAvailable: true)

    // Given running and quit apps in every section
    // When the window reads them
    // Then it lists the running hidden ones, then the always-hidden ones, each by name
    func test_content_listsRunningHiddenAppsBySectionAndName() {
        let candidates = [app("Zoom", .hidden), app("amphetamine", .hidden), app("Paste", .alwaysHidden),
                          app("Shown", .visible), app("Quit", .hidden, running: false)]
        let content = IconWindowModel.content(candidates: candidates, environment: ready)
        guard case .tiles(let hidden, let alwaysHidden) = content else { return XCTFail("expected tiles, got \(content)") }
        XCTAssertEqual(hidden.map(\.name), ["amphetamine", "Zoom"])
        XCTAssertEqual(alwaysHidden.map(\.name), ["Paste"])
        XCTAssertEqual(content.tileCount, 3)
    }

    func test_content_edgeStates() {
        let candidates = [app("Paste", .hidden)]
        XCTAssertEqual(IconWindowModel.content(candidates: candidates,
                                               environment: PaletteEnvironment(accessibilityTrusted: false, engineAvailable: false)),
                       .accessibilityOff, "the permission comes first")
        XCTAssertEqual(IconWindowModel.content(candidates: candidates,
                                               environment: PaletteEnvironment(accessibilityTrusted: true, engineAvailable: false)),
                       .engineUnavailable)
        XCTAssertEqual(IconWindowModel.content(candidates: [app("Shown", .visible)], environment: ready), .nothingHidden)
        var presenting = ready
        presenting.hiddenWhilePresenting = ["com.paste"]
        XCTAssertEqual(IconWindowModel.content(candidates: candidates, environment: presenting), .nothingHidden,
                       "presentation mode keeps sensitive apps out of the window")
    }

    func test_rowsAndColumns() {
        XCTAssertEqual(IconWindowModel.rows(Array(1...8), columns: 6), [[1, 2, 3, 4, 5, 6], [7, 8]])
        XCTAssertEqual(IconWindowModel.rows([Int](), columns: 6), [])
        let few = IconWindowContent.tiles(hidden: [IconWindowTile(bundleIdentifier: "a", name: "A", section: .hidden)],
                                          alwaysHidden: [])
        XCTAssertEqual(IconWindowModel.columns(for: few), 1)
        let many = IconWindowContent.tiles(hidden: (0..<9).map { IconWindowTile(bundleIdentifier: "\($0)", name: "\($0)", section: .hidden) },
                                           alwaysHidden: [])
        XCTAssertEqual(IconWindowModel.columns(for: many), IconWindowModel.maxColumns)
    }

    // Given each arrow click mode
    // When the collapsed arrow is clicked
    // Then only window mode, or automatic mode on a full bar, opens the window
    func test_policy_opensWindow() {
        for overflows in [false, true] {
            XCTAssertFalse(IconWindowPolicy.opensWindow(mode: .expand, isCollapsed: true, usesNativeEngine: true, barOverflows: overflows))
            XCTAssertTrue(IconWindowPolicy.opensWindow(mode: .window, isCollapsed: true, usesNativeEngine: true, barOverflows: overflows))
            XCTAssertEqual(IconWindowPolicy.opensWindow(mode: .automatic, isCollapsed: true, usesNativeEngine: true, barOverflows: overflows), overflows)
        }
        XCTAssertFalse(IconWindowPolicy.opensWindow(mode: .window, isCollapsed: false, usesNativeEngine: true, barOverflows: true),
                       "a click on the expanded arrow collapses it")
        XCTAssertFalse(IconWindowPolicy.opensWindow(mode: .window, isCollapsed: true, usesNativeEngine: false, barOverflows: true),
                       "only the native engine can open an app from the window")
    }

    func test_policy_readsOverflowOnlyWhenAutomaticAndUnknown() {
        XCTAssertTrue(IconWindowPolicy.needsOverflowRead(mode: .automatic, isCollapsed: true, usesNativeEngine: true, remembersOverflow: false))
        XCTAssertFalse(IconWindowPolicy.needsOverflowRead(mode: .automatic, isCollapsed: true, usesNativeEngine: true, remembersOverflow: true))
        XCTAssertFalse(IconWindowPolicy.needsOverflowRead(mode: .window, isCollapsed: true, usesNativeEngine: true, remembersOverflow: false))
        XCTAssertFalse(IconWindowPolicy.needsOverflowRead(mode: .automatic, isCollapsed: false, usesNativeEngine: true, remembersOverflow: false))
    }

    func test_policy_foldsAnOverflowingClickExpandInAutomaticModeOnly() {
        XCTAssertTrue(IconWindowPolicy.foldsIntoWindow(mode: .automatic, fromArrowClick: true, movedIntoOverflow: ["com.paste"]))
        XCTAssertFalse(IconWindowPolicy.foldsIntoWindow(mode: .automatic, fromArrowClick: true, movedIntoOverflow: []))
        XCTAssertFalse(IconWindowPolicy.foldsIntoWindow(mode: .automatic, fromArrowClick: false, movedIntoOverflow: ["com.paste"]),
                       "the hotkey or the window's own expand button keeps the bar expanded")
        XCTAssertFalse(IconWindowPolicy.foldsIntoWindow(mode: .window, fromArrowClick: true, movedIntoOverflow: ["com.paste"]))
    }

    func test_overflowMemory() {
        var memory = IconWindowOverflowMemory()
        XCTAssertFalse(memory.overflowed)
        memory.recordExpand(movedIntoOverflow: ["com.paste"])
        XCTAssertTrue(memory.overflowed)
        memory.recordExpand(movedIntoOverflow: [])
        XCTAssertFalse(memory.overflowed, "an expand that fit forgets the overflow")
        memory.recordExpand(movedIntoOverflow: ["com.paste"])
        memory.displaysChanged()
        XCTAssertFalse(memory.overflowed, "a display change makes room unknown again")
    }

    func test_arrowClickMode_readsUnknownAsAutomatic() {
        XCTAssertEqual(ArrowClickMode(storedValue: nil), .automatic)
        XCTAssertEqual(ArrowClickMode(storedValue: "bogus"), .automatic)
        XCTAssertEqual(ArrowClickMode(storedValue: "window"), .window)
        XCTAssertEqual(ArrowClickMode(storedValue: "expand"), .expand)
    }
}

#if HIDDENBAR_NATIVE_VISIBILITY

final class IconWindowControllerTests: XCTestCase {

    private final class FakeResolver: MenuBarAppResolving {
        var running: Set<String> = ["com.paste", "com.1password", "com.amphetamine", "com.zoom"]
        let names = ["com.paste": "Paste", "com.1password": "1Password", "com.amphetamine": "Amphetamine", "com.zoom": "zoom.us"]
        func name(of bundle: String) -> String? { names[bundle] }
        func icon(of bundle: String) -> NSImage? { NSImage(size: NSSize(width: 16, height: 16)) }
        func isRunning(_ bundle: String) -> Bool { running.contains(bundle) }
    }

    private final class FakeHost {
        var environment = PaletteEnvironment(accessibilityTrusted: true, engineAvailable: true)
        var opened: [String] = []
        var finish: ((PaletteOpenResult) -> Void)?
        var moves: [String] = []
        var expands = 0

        var host: IconWindowHost {
            IconWindowHost(environment: { [unowned self] in environment },
                           arrowFrame: { CGRect(x: 1300, y: 975, width: 20, height: 25) },
                           open: { [unowned self] bundle, done in opened.append(bundle); finish = done },
                           move: { [unowned self] section, bundle in moves.append("\(bundle)=\(section)") },
                           expandBar: { [unowned self] in expands += 1 },
                           openAccessibilitySettings: {},
                           openSettings: {})
        }
    }

    private var suite: String!
    private var defaults: UserDefaults!
    private var center: NotificationCenter!
    private var catalog: MenuBarItemCatalog!
    private var fake: FakeHost!
    private var clock: TimeInterval = 100
    private var window: IconWindowController!

    override func setUp() {
        super.setUp()
        suite = "IconWindowControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        center = NotificationCenter()
        catalog = MenuBarItemCatalog(defaults: defaults, center: center, resolver: FakeResolver(), pinnedTable: { [:] })
        catalog.record(layout: MenuBarLayout(sections: ["com.paste": .hidden, "com.1password": .hidden,
                                                         "com.amphetamine": .alwaysHidden, "com.zoom": .visible]), inventory: [])
        fake = FakeHost()
        let screen = PaletteScreen(frame: CGRect(x: 0, y: 0, width: 1600, height: 1000), visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 975))
        window = IconWindowController(host: fake.host, catalog: catalog, screens: { [screen] }, pointer: { CGPoint(x: 1300, y: 990) },
                                      now: { [unowned self] in clock }, notifications: center, ordersPanelFront: false)
    }

    override func tearDown() {
        window.close()
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func tiles() -> [IconTileView] {
        func all(_ view: NSView) -> [NSView] { view.subviews + view.subviews.flatMap(all) }
        return window.contentView.map { all($0).compactMap { $0 as? IconTileView } } ?? []
    }

    private func texts() -> [String] {
        func all(_ view: NSView) -> [NSView] { view.subviews + view.subviews.flatMap(all) }
        return window.contentView.map { all($0).compactMap { ($0 as? NSTextField)?.stringValue } } ?? []
    }

    // Given two hidden apps and one always hidden
    // When the window shows
    // Then it draws one tile per app, under the arrow
    func test_show_drawsATilePerHiddenApp() throws {
        window.show()
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(tiles().map { $0.accessibilityLabel() ?? "" }, ["1Password", "Paste", "Amphetamine"])
        let frame = try XCTUnwrap(window.panel?.frame)
        XCTAssertLessThanOrEqual(frame.maxY, 975, "the window hangs below the menu bar")
    }

    // Given the window is open
    // When a tile is clicked and its menu opens
    // Then the app is opened through the host and the window closes
    func test_tileClick_opensTheApp_thenCloses() {
        window.show()
        window.open("com.paste")
        XCTAssertEqual(fake.opened, ["com.paste"])
        XCTAssertEqual(window.openingBundle, "com.paste")
        window.open("com.1password")
        XCTAssertEqual(fake.opened, ["com.paste"], "one app opens at a time")
        fake.finish?(.opened)
        XCTAssertFalse(window.isVisible)
    }

    // Given macOS found no room for the app's icon
    // When the open ends
    // Then the window stays and says so, naming the app
    func test_noItem_staysOpenAndSaysWhy() {
        window.show()
        window.open("com.paste")
        fake.finish?(.noItem)
        XCTAssertTrue(window.isVisible)
        XCTAssertNil(window.openingBundle)
        XCTAssertTrue(window.failure?.contains("Paste") ?? false)
        XCTAssertTrue(texts().contains { $0.contains("Paste") && $0 != "Paste" })
    }

    // Given the window just closed because the arrow click took focus
    // When that same click toggles it
    // Then it stays closed; a later click opens it
    func test_toggleRightAfterClose_staysClosed() {
        window.show()
        window.close()
        window.toggle()
        XCTAssertFalse(window.isVisible)
        clock += IconWindowController.reopenGuard + 0.1
        window.toggle()
        XCTAssertTrue(window.isVisible)
    }

    func test_move_goesThroughTheHost() {
        window.show()
        tiles().first?.onMove?(.visible)
        XCTAssertEqual(fake.moves, ["com.1password=visible"])
    }

    func test_accessibilityOff_showsNoTiles() {
        fake.environment = PaletteEnvironment(accessibilityTrusted: false, engineAvailable: true)
        window.show()
        XCTAssertTrue(tiles().isEmpty)
        XCTAssertEqual(window.content, .accessibilityOff)
    }
}

#endif
