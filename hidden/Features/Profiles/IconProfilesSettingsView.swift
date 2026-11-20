//
//  IconProfilesSettingsView.swift
//  Coulisse
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

#if HIDDENBAR_NATIVE_VISIBILITY
import AppKit

/// The Profiles group at the top of Settings › Icons: one line per profile with
/// its name, its rule and a way to use it now.
final class IconProfilesSettingsView: NSStackView {
    private let manager: IconProfileManager
    private let connectedDisplays: () -> [String]
    private var observer: NSObjectProtocol?

    init(manager: IconProfileManager = .shared,
         connectedDisplays: @escaping () -> [String] = { IconProfileManager.liveContext().externalDisplays }) {
        self.manager = manager
        self.connectedDisplays = connectedDisplays
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 6
        translatesAutoresizingMaskIntoConstraints = false
        observer = NotificationCenter.default.addObserver(forName: .iconProfilesChanged, object: nil, queue: .main) { [weak self] _ in
            self?.rebuild()
        }
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit {
        observer.map(NotificationCenter.default.removeObserver)
    }

    /// The rule choices a popup offers: the named displays connected now and those
    /// rules already name, so a rule for the office display survives at home.
    static func ruleChoices(connected: [String], named: [String]) -> [IconProfileRule] {
        var displays: [String] = []
        for name in connected + named where !displays.contains(name) { displays.append(name) }
        return [.manual, IconProfileRule(trigger: .externalDisplay, displayName: nil)]
            + displays.map { IconProfileRule(trigger: .externalDisplay, displayName: $0) }
            + [IconProfileRule(trigger: .noExternalDisplay), IconProfileRule(trigger: .onBattery), IconProfileRule(trigger: .onPower)]
    }

    static func title(for rule: IconProfileRule) -> String {
        switch rule.trigger {
        case .manual: return "Manual".localized
        case .externalDisplay:
            if let name = rule.displayName { return String(format: "Display “%@” connected".localized, name) }
            return "Any external display connected".localized
        case .noExternalDisplay: return "No external display".localized
        case .onBattery: return "On battery".localized
        case .onPower: return "On power adapter".localized
        }
    }

    private func rebuild() {
        arrangedSubviews.forEach { $0.removeFromSuperview() }
        let explanation = "Save several icon layouts and let Coulisse switch between them, for example when an external display is connected or the Mac runs on battery.".localized
        guard manager.isOn else {
            let create = NSButton(title: "Create Profiles".localized, target: self, action: #selector(createPressed))
            create.controlSize = .small
            add(SettingsGroupView(rows: [SettingsForm.row("Profiles".localized, caption: explanation, control: create)]))
            return
        }
        add(SettingsForm.caption("The list below edits the active profile. Coulisse picks the profile whose rule fits best; with none, the one you used last by hand.".localized))
        let profiles = manager.profiles
        let choices = Self.ruleChoices(connected: connectedDisplays(), named: profiles.compactMap(\.rule.displayName))
        var rows = profiles.map { row(for: $0, choices: choices, canRemove: true) }
        let addButton = NSButton(title: "Add a Profile".localized, target: self, action: #selector(addPressed))
        addButton.controlSize = .small
        rows.append(SettingsForm.row("", control: addButton))
        add(SettingsGroupView(rows: rows))
    }

    private func add(_ view: NSView) {
        addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }

    private func row(for profile: IconProfile, choices: [IconProfileRule], canRemove: Bool) -> NSView {
        let isActive = profile.id == manager.activeID
        let dot = NSImageView(image: NSImage(systemSymbolName: isActive ? "checkmark.circle.fill" : "circle",
                                             accessibilityDescription: isActive ? "Active".localized : nil) ?? NSImage())
        dot.contentTintColor = isActive ? .controlAccentColor : .tertiaryLabelColor

        let name = ProfileNameField(string: profile.name)
        name.profileID = profile.id
        name.target = self
        name.action = #selector(nameEdited(_:))
        name.controlSize = .small
        name.font = .systemFont(ofSize: NSFont.systemFontSize, weight: isActive ? .semibold : .regular)
        name.translatesAutoresizingMaskIntoConstraints = false
        name.widthAnchor.constraint(equalToConstant: 130).isActive = true

        let popup = ProfileRulePopUp(frame: .zero, pullsDown: false)
        popup.controlSize = .small
        popup.profileID = profile.id
        popup.rules = choices
        for rule in choices { popup.addItem(withTitle: Self.title(for: rule)) }
        popup.selectItem(at: choices.firstIndex(of: profile.rule) ?? 0)
        popup.target = self
        popup.action = #selector(rulePicked(_:))

        let use = ProfileButton(title: isActive ? "Active".localized : "Use".localized, target: self, action: #selector(usePressed(_:)))
        use.profileID = profile.id
        use.controlSize = .small
        use.isEnabled = !isActive

        let remove = ProfileButton(title: "Remove".localized, target: self, action: #selector(removePressed(_:)))
        remove.profileID = profile.id
        remove.controlSize = .small
        remove.isHidden = !canRemove

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let line = NSStackView(views: [dot, name, spacer, popup, use, remove])
        line.spacing = 8
        line.alignment = .centerY
        line.edgeInsets = NSEdgeInsets(top: 6, left: SettingsMetrics.rowInset, bottom: 6, right: SettingsMetrics.rowInset)
        line.identifier = NSUserInterfaceItemIdentifier("profile.\(profile.id)")
        return line
    }

    @objc private func createPressed() { manager.createInitialProfiles() }
    @objc private func addPressed() { manager.add() }

    @objc private func nameEdited(_ sender: ProfileNameField) {
        guard let id = sender.profileID else { return }
        manager.rename(id, to: sender.stringValue)
    }

    @objc private func rulePicked(_ sender: ProfileRulePopUp) {
        guard let id = sender.profileID, sender.rules.indices.contains(sender.indexOfSelectedItem) else { return }
        manager.setRule(id, sender.rules[sender.indexOfSelectedItem])
    }

    @objc private func usePressed(_ sender: ProfileButton) {
        guard let id = sender.profileID else { return }
        manager.choose(id)
    }

    @objc private func removePressed(_ sender: ProfileButton) {
        guard let id = sender.profileID else { return }
        manager.remove(id)
    }
}

private final class ProfileNameField: NSTextField {
    var profileID: String?
}

private final class ProfileRulePopUp: NSPopUpButton {
    var profileID: String?
    var rules: [IconProfileRule] = []
}

private final class ProfileButton: NSButton {
    var profileID: String?
}
#endif
