//
//  AppRule.swift
//  Coulisse
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

import AppKit

/// "Show the icon of `bundle` while `frontApp` is the app in front." A hidden
/// icon comes into the menu bar for as long as that app is used, then hides again.
struct AppRule: Codable, Equatable {
    var id: String
    /// The app whose menu bar icon shows.
    var bundle: String
    /// The app that has to be in front; usually the same app.
    var frontApp: String
}

enum AppRuleResolver {
    /// The icons the rules show while `front` is the active app.
    static func shown(by rules: [AppRule], front: String?) -> Set<String> {
        guard let front else { return [] }
        return Set(rules.filter { $0.frontApp == front }.map(\.bundle))
    }
}

struct AppRuleStore {
    static let key = "appRules"
    let defaults: UserDefaults

    var rules: [AppRule] {
        get {
            guard let data = defaults.data(forKey: Self.key),
                  let decoded = try? JSONDecoder().decode([AppRule].self, from: data) else { return [] }
            return decoded
        }
        nonmutating set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: Self.key)
            } else if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Self.key)
            }
        }
    }
}

extension Notification.Name {
    /// The per-app rules were added, changed or removed. Main thread.
    static let appRulesChanged = Notification.Name("appRulesChanged")
}

/// Follows the app in front and tells the engine which hidden icons the rules
/// show now. Reads only which app is active: no window, no screen content.
final class AppRuleManager {
    static let shared = AppRuleManager()

    /// Called on the main thread when `shownNow` changed.
    var onChange: (() -> Void)?

    private let store: AppRuleStore
    private let frontApp: () -> String?
    private let workspace: NotificationCenter
    private var observer: NSObjectProtocol?
    private(set) var shownNow: Set<String> = []

    init(store: AppRuleStore = AppRuleStore(defaults: AppDefaults.store),
         frontApp: @escaping () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier },
         workspace: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.store = store
        self.frontApp = frontApp
        self.workspace = workspace
    }

    deinit {
        observer.map(workspace.removeObserver)
    }

    var rules: [AppRule] { store.rules }

    func start() {
        guard observer == nil else { return }
        observer = workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    func refresh() {
        let now = AppRuleResolver.shown(by: store.rules, front: frontApp())
        guard now != shownNow else { return }
        shownNow = now
        onChange?()
    }

    // MARK: Editing

    func add(bundle: String, frontApp: String? = nil) {
        var all = rules
        all.append(AppRule(id: UUID().uuidString, bundle: bundle, frontApp: frontApp ?? bundle))
        save(all)
    }

    func update(_ id: String, bundle: String? = nil, frontApp: String? = nil) {
        var all = rules
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        if let bundle { all[index].bundle = bundle }
        if let frontApp { all[index].frontApp = frontApp }
        save(all)
    }

    func remove(_ id: String) {
        save(rules.filter { $0.id != id })
    }

    private func save(_ all: [AppRule]) {
        store.rules = all
        NotificationCenter.default.post(name: .appRulesChanged, object: nil)
        refresh()
    }
}
