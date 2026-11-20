//
//  MenuBarTintController.swift
//  Coulisse
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

import AppKit

/// One borderless window per display, just below the menu bar's own level: the
/// menu bar draws over it, app windows stay under it, and it never takes a click.
/// Full-screen spaces, where the menu bar hides, do not show it.
final class MenuBarTintController {
    static let shared = MenuBarTintController()

    private var windows: [NSWindow] = []
    private var observers: [NSObjectProtocol] = []

    func start() {
        guard observers.isEmpty else { return }
        for name in [NSApplication.didChangeScreenParametersNotification, .prefsChanged] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.sync()
            })
        }
        sync()
    }

    func sync() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        guard Preferences.menuBarTintEnabled else { return }
        let color = MenuBarTintColor.color(hex: Preferences.menuBarTintColor)
            .withAlphaComponent(CGFloat(Preferences.menuBarTintOpacity))
        let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) - 1)
        for screen in NSScreen.screens {
            guard let band = MenuBarTintColor.band(frame: screen.frame, visibleFrame: screen.visibleFrame) else { continue }
            let window = MenuBarTintWindow(contentRect: band, styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.hasShadow = false
            window.backgroundColor = color
            window.ignoresMouseEvents = true
            window.level = level
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.setFrame(band, display: false)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }
}

/// AppKit moves a window out from under the menu bar; this one belongs there.
private final class MenuBarTintWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
