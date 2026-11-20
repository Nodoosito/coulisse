//
//  IconProfileManager.swift
//  Coulisse
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

#if HIDDENBAR_NATIVE_VISIBILITY
import AppKit
import IOKit.ps

extension Notification.Name {
    /// The profiles, or the active one, changed. Main thread.
    static let iconProfilesChanged = Notification.Name("iconProfilesChanged")
}

/// Keeps one pinned-sections table per profile and puts the right one in place:
/// by hand from the arrow's menu or Settings, or by itself when a display is
/// connected or removed, or the Mac switches between battery and power adapter.
/// Edits the user makes to the sections go to the active profile.
final class IconProfileManager {
    static let shared = IconProfileManager()

    private let store: IconProfileStore
    private let table: MenuBarSectionMemory
    private let center: NotificationCenter
    private let context: () -> IconProfileContext
    private var applying = false
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var powerSource: CFRunLoopSource?
    private var lastContext: IconProfileContext?

    init(store: IconProfileStore = IconProfileStore(defaults: AppDefaults.store),
         table: MenuBarSectionMemory = UserDefaultsPinnedSections(),
         center: NotificationCenter = .default,
         context: @escaping () -> IconProfileContext = IconProfileManager.liveContext) {
        self.store = store
        self.table = table
        self.center = center
        self.context = context
    }

    deinit {
        observers.forEach { $0.0.removeObserver($0.1) }
        if let powerSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode) }
    }

    var profiles: [IconProfile] { store.profiles }
    var activeID: String? { store.activeID }
    var active: IconProfile? { profiles.first { $0.id == store.activeID } }
    /// Profiles mean something from two on; with fewer the feature is off.
    var isOn: Bool { profiles.count >= 2 }

    // MARK: Watching

    func start() {
        // Synchronous (no queue), so `applying` covers the post this class makes itself.
        observers.append((center, center.addObserver(forName: .pinnedSectionsChanged, object: nil, queue: nil) { [weak self] _ in
            self?.tableChanged()
        }))
        let screens = NotificationCenter.default
        observers.append((screens, screens.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                       object: nil, queue: .main) { [weak self] _ in
            self?.contextMayHaveChanged()
        }))
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ pointer in
            guard let pointer else { return }
            let manager = Unmanaged<IconProfileManager>.fromOpaque(pointer).takeUnretainedValue()
            DispatchQueue.main.async { manager.contextMayHaveChanged() }
        }, opaque)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }
        contextMayHaveChanged()
    }

    /// Displays and power report many changes that leave the context as it was.
    func contextMayHaveChanged() {
        let now = context()
        guard now != lastContext else { return }
        lastContext = now
        evaluate(now)
    }

    private func evaluate(_ now: IconProfileContext) {
        guard isOn, let target = IconProfileResolver.profile(for: now, in: profiles, baseID: store.baseID),
              target.id != store.activeID else { return }
        activate(target.id)
    }

    static func liveContext() -> IconProfileContext {
        let external = NSScreen.screens.filter { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(number.uint32Value) == 0
        }.map(\.localizedName)
        let source = IOPSGetProvidingPowerSourceType(nil)?.takeUnretainedValue() as String?
        return IconProfileContext(externalDisplays: external, onBattery: source == "Battery Power")
    }

    // MARK: Choosing

    /// A pick by hand: it also becomes the profile to return to when no rule fits.
    func choose(_ id: String) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        store.baseID = id
        if id != store.activeID { activate(id) }
    }

    private func activate(_ id: String) {
        var all = profiles
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        // The profile being left keeps what the bar holds now.
        if let leaving = all.firstIndex(where: { $0.id == store.activeID }) {
            all[leaving].sections = currentSections()
        }
        store.profiles = all
        store.activeID = id
        applying = true
        table.sections = all[index].sections.compactMapValues(MenuBarSection.init(rawValue:))
        center.post(name: .pinnedSectionsChanged, object: nil)
        applying = false
        NSLog("IconProfiles: \(all[index].name) is active")
        center.post(name: .iconProfilesChanged, object: nil)
    }

    private func currentSections() -> [String: Int] {
        table.sections.mapValues(\.rawValue)
    }

    // A section the user changed goes to the active profile.
    private func tableChanged() {
        guard !applying, isOn, let id = store.activeID else { return }
        var all = profiles
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        let now = currentSections()
        guard all[index].sections != now else { return }
        all[index].sections = now
        store.profiles = all
    }

    // MARK: Editing

    /// Turns profiles on: the current layout becomes "Default", and a copy of it the second profile.
    func createInitialProfiles() {
        guard profiles.isEmpty else { return add() }
        let now = currentSections()
        let first = IconProfile(id: UUID().uuidString, name: "Default".localized, rule: .manual, sections: now)
        let second = IconProfile(id: UUID().uuidString,
                                 name: IconProfileResolver.newName(format: "Profile %d".localized, existing: [first.name]),
                                 rule: .manual, sections: now)
        store.profiles = [first, second]
        store.activeID = first.id
        store.baseID = first.id
        changed()
    }

    /// A new profile starts as a copy of the current layout.
    func add() {
        var all = profiles
        all.append(IconProfile(id: UUID().uuidString,
                               name: IconProfileResolver.newName(format: "Profile %d".localized, existing: all.map(\.name)),
                               rule: .manual, sections: currentSections()))
        store.profiles = all
        changed()
    }

    func rename(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return changed() }
        update(id) { $0.name = trimmed }
    }

    func setRule(_ id: String, _ rule: IconProfileRule) {
        update(id) { $0.rule = rule }
        lastContext = nil
        contextMayHaveChanged()
    }

    /// Fewer than two profiles left turns the feature off; the bar keeps its layout.
    func remove(_ id: String) {
        var all = profiles
        all.removeAll { $0.id == id }
        if all.count < 2 {
            store.profiles = []
            store.activeID = nil
            store.baseID = nil
            return changed()
        }
        store.profiles = all
        if store.baseID == id { store.baseID = all.first?.id }
        if store.activeID == id {
            store.activeID = nil
            if let next = all.first { activate(next.id) }
        }
        changed()
    }

    private func update(_ id: String, _ change: (inout IconProfile) -> Void) {
        var all = profiles
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        change(&all[index])
        store.profiles = all
        changed()
    }

    private func changed() {
        center.post(name: .iconProfilesChanged, object: nil)
    }
}
#endif
