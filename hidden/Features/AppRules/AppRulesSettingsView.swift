//
//  AppRulesSettingsView.swift
//  Coulisse
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

#if HIDDENBAR_NATIVE_VISIBILITY
import AppKit

/// The per-app rules group in Settings › Icons: "Show [app] when [app] is in front".
final class AppRulesSettingsView: NSStackView {
    private let manager: AppRuleManager
    private let catalog: MenuBarItemCatalog
    private var observers: [NSObjectProtocol] = []

    init(manager: AppRuleManager = .shared, catalog: MenuBarItemCatalog = .shared) {
        self.manager = manager
        self.catalog = catalog
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 6
        translatesAutoresizingMaskIntoConstraints = false
        for name in [Notification.Name.appRulesChanged, .menuBarCatalogChanged] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.rebuild()
            })
        }
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// Apps a rule can show: the hidden and always-hidden ones, plus any a rule names.
    static func iconChoices(entries: [MenuBarCatalogEntry], named: [String]) -> [String] {
        var bundles = entries.filter { $0.section != .visible }.map(\.bundleIdentifier)
        for bundle in named where !bundles.contains(bundle) { bundles.append(bundle) }
        return bundles
    }

    /// Apps that can be in front: the regular apps running now, plus any a rule names.
    static func frontChoices(running: [String], named: [String], excluding own: String?) -> [String] {
        var bundles: [String] = []
        for bundle in running + named where bundle != own && !bundles.contains(bundle) { bundles.append(bundle) }
        return bundles
    }

    private func name(of bundle: String) -> String {
        catalog.entry(for: bundle)?.name ?? WorkspaceAppResolver().name(of: bundle) ?? bundle
    }

    private func rebuild() {
        arrangedSubviews.forEach { $0.removeFromSuperview() }
        let rules = manager.rules
        let icons = Self.iconChoices(entries: catalog.entries, named: rules.map(\.bundle))
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .compactMap(\.bundleIdentifier)
            .sorted { name(of: $0).localizedStandardCompare(name(of: $1)) == .orderedAscending }

        let addButton = NSButton(title: "Add a Rule".localized, target: self, action: #selector(addPressed))
        addButton.controlSize = .small
        let unruled = icons.filter { icon in !rules.contains { $0.bundle == icon } }
        addButton.isEnabled = !unruled.isEmpty
        let explanation = unruled.isEmpty && rules.isEmpty
            ? "Hide an icon first to add a rule for it.".localized
            : "Show a hidden icon while you use an app. When you switch to another app, it hides again.".localized
        var rows: [NSView] = [SettingsForm.row("Per-app rules".localized, caption: explanation, control: addButton)]
        for rule in rules {
            rows.append(row(for: rule, icons: icons,
                            fronts: Self.frontChoices(running: running, named: rules.map(\.frontApp) + [rule.bundle],
                                                      excluding: Bundle.main.bundleIdentifier)))
        }
        let group = SettingsGroupView(rows: rows)
        addArrangedSubview(group)
        group.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }

    private func row(for rule: AppRule, icons: [String], fronts: [String]) -> NSView {
        let show = NSTextField(labelWithString: "Show".localized)
        let iconPopup = RulePopUp(frame: .zero, pullsDown: false)
        iconPopup.controlSize = .small
        iconPopup.ruleID = rule.id
        iconPopup.bundles = icons
        for bundle in icons {
            iconPopup.addItem(withTitle: name(of: bundle))
            iconPopup.lastItem?.image = catalog.entry(for: bundle)?.icon.resized(to: 16)
        }
        iconPopup.selectItem(at: icons.firstIndex(of: rule.bundle) ?? 0)
        iconPopup.target = self
        iconPopup.action = #selector(iconPicked(_:))

        // The first choice is the app itself; the others name another app.
        let frontPopup = RulePopUp(frame: .zero, pullsDown: false)
        frontPopup.controlSize = .small
        frontPopup.ruleID = rule.id
        frontPopup.bundles = [rule.bundle] + fronts.filter { $0 != rule.bundle }
        frontPopup.addItem(withTitle: "when it is in front".localized)
        for bundle in frontPopup.bundles.dropFirst() {
            frontPopup.addItem(withTitle: String(format: "when %@ is in front".localized, name(of: bundle)))
        }
        frontPopup.selectItem(at: frontPopup.bundles.firstIndex(of: rule.frontApp) ?? 0)
        frontPopup.target = self
        frontPopup.action = #selector(frontPicked(_:))

        let remove = RuleButton(title: "Remove".localized, target: self, action: #selector(removePressed(_:)))
        remove.ruleID = rule.id
        remove.controlSize = .small

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let line = NSStackView(views: [show, iconPopup, frontPopup, spacer, remove])
        line.spacing = 6
        line.alignment = .centerY
        line.edgeInsets = NSEdgeInsets(top: 6, left: SettingsMetrics.rowInset, bottom: 6, right: SettingsMetrics.rowInset)
        return line
    }

    @objc private func addPressed() {
        let rules = manager.rules
        let icons = Self.iconChoices(entries: catalog.entries, named: [])
        guard let first = icons.first(where: { icon in !rules.contains { $0.bundle == icon } }) else { return }
        manager.add(bundle: first)
    }

    @objc private func iconPicked(_ sender: RulePopUp) {
        guard let id = sender.ruleID, sender.bundles.indices.contains(sender.indexOfSelectedItem),
              let rule = manager.rules.first(where: { $0.id == id }) else { return }
        let bundle = sender.bundles[sender.indexOfSelectedItem]
        // A rule that followed its own app keeps doing so for the new one.
        manager.update(id, bundle: bundle, frontApp: rule.frontApp == rule.bundle ? bundle : nil)
    }

    @objc private func frontPicked(_ sender: RulePopUp) {
        guard let id = sender.ruleID, sender.bundles.indices.contains(sender.indexOfSelectedItem) else { return }
        manager.update(id, frontApp: sender.bundles[sender.indexOfSelectedItem])
    }

    @objc private func removePressed(_ sender: RuleButton) {
        guard let id = sender.ruleID else { return }
        manager.remove(id)
    }
}

private final class RulePopUp: NSPopUpButton {
    var ruleID: String?
    var bundles: [String] = []
}

private final class RuleButton: NSButton {
    var ruleID: String?
}

private extension NSImage {
    func resized(to side: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            self.draw(in: rect)
            return true
        }
    }
}
#endif
