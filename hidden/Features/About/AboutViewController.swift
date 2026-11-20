//
//  AboutViewController.swift
//  Hidden Bar
//
//  Created by phucld on 12/19/19.
//  Copyright © 2019 Console Labs. All rights reserved.
//

import Cocoa

/// Version and build, updates (direct build only), and where to get help.
final class AboutViewController: SettingsPaneController {
    static let changelogURL = URL(string: "https://github.com/consolelabs/hidden/blob/develop/CHANGELOG.md")!
    /// Coulisse is a fork: credit the original project, MIT license.
    static let upstreamURL = URL(string: "https://github.com/consolelabs/hidden")!
    static let checkForUpdatesIdentifier = NSUserInterfaceItemIdentifier("checkForUpdates")

    /// "Version 1.12 (18) · Direct download"; support needs to know which build.
    static func versionLine(version: String?, build: String?, kind: SettingsBuild) -> String {
        var line = "Version".localized + " " + (version ?? "?")
        if let build { line += " (\(build))" }
        return line + " · " + (kind == .direct ? "Direct download" : "Mac App Store").localized
    }

    private var lastCheckedCaption: NSTextField?

    /// Coulisse ships without an update feed for now; the Sparkle rows show only
    /// when the build defines HIDDENBAR_SPARKLE again.
    static func hasUpdater(_ build: SettingsBuild) -> Bool {
        #if HIDDENBAR_SPARKLE
        return build == .direct
        #else
        return false
        #endif
    }

    override func buildForm() {
        let whatsNew = SettingsForm.link("What's new".localized, url: Self.changelogURL)
        if Self.hasUpdater(context.build) {
            let autoCheck = boundSwitch("SUEnableAutomaticChecks", read: { Self.automaticallyChecksForUpdates },
                                        write: { Self.automaticallyChecksForUpdates = $0 })
            let autoRow = SettingsForm.row("Check for updates automatically".localized, caption: Self.lastCheckedText(), control: autoCheck)
            let check = NSButton(title: "Check for Updates…".localized, target: self, action: #selector(checkForUpdates(_:)))
            check.identifier = Self.checkForUpdatesIdentifier
            check.bezelStyle = .rounded
            let linkRow = Self.linkRow(whatsNew, trailing: check)
            addSection(nil, rows: [header(), autoRow, linkRow])
        } else {
            addSection(nil, rows: [header()])
        }

        addSection(nil, rows: [
            Self.linkRow(SettingsForm.link("Based on Hidden Bar".localized, url: Self.upstreamURL),
                         caption: "Free and open source, MIT license.".localized),
        ])
    }

    private func header() -> NSView {
        let icon = NSImageView(image: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage ?? NSImage())
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true
        let name = NSTextField(labelWithString: "Coulisse")
        name.font = .systemFont(ofSize: 20, weight: .bold)
        let tagline = NSTextField(labelWithString: "Keeps your menu bar tidy.".localized)
        tagline.textColor = .secondaryLabelColor
        let version = NSTextField(labelWithString: Self.versionLine(version: Bundle.main.releaseVersionNumber,
                                                                  build: Bundle.main.buildVersionNumber, kind: context.build))
        version.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        version.textColor = .secondaryLabelColor
        version.isSelectable = true
        let texts = NSStackView(views: [name, tagline, version])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 3
        texts.setCustomSpacing(6, after: tagline)
        let row = NSStackView(views: [icon, texts])
        row.spacing = 16
        row.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        row.alignment = .centerY
        return row
    }

    private static func linkRow(_ link: NSButton, caption: String? = nil, trailing: NSView? = nil) -> NSView {
        let row = SettingsForm.row("", caption: caption, control: trailing)
        // Put the link where the title label sits.
        func all(_ view: NSView) -> [NSView] { view.subviews + view.subviews.flatMap(all) }
        guard let title = all(row).compactMap({ $0 as? NSTextField }).first(where: { $0.stringValue.isEmpty }),
              let texts = title.superview as? NSStackView else { return row }
        texts.insertArrangedSubview(link, at: 0)
        texts.removeArrangedSubview(title)
        title.removeFromSuperview()
        return row
    }

    private static func lastCheckedText() -> String? {
        #if HIDDENBAR_SPARKLE
        guard let date = UpdateController.shared.lastUpdateCheckDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return String(format: "Last checked %@.".localized, formatter.string(from: date))
        #else
        return nil
        #endif
    }

    private static var automaticallyChecksForUpdates: Bool {
        get {
            #if HIDDENBAR_SPARKLE
            return UpdateController.shared.automaticallyChecksForUpdates
            #else
            return false
            #endif
        }
        set {
            #if HIDDENBAR_SPARKLE
            UpdateController.shared.automaticallyChecksForUpdates = newValue
            #endif
        }
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        #if HIDDENBAR_SPARKLE
        UpdateController.shared.checkForUpdates()
        #endif
    }
}
