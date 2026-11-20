//
//  SettingsBackup.swift
//  Coulisse
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

#if HIDDENBAR_NATIVE_VISIBILITY
import AppKit

/// Settings, profiles and per-app rules in a property list file, to carry to
/// another Mac or keep across a reinstall. Only known keys with the expected
/// type go in or out; nothing else of the defaults domain is touched.
enum SettingsBackup {
    static let versionKey = "CoulisseSettingsVersion"
    static let version = 1
    static let fileExtension = "coulisse-settings"

    /// Every user setting, plus what Coulisse adds: the profiles and the rules.
    static var keys: [String: AppStoreSettingsImport.Kind] {
        AppStoreSettingsImport.importableKeys.merging([
            AppRuleStore.key: .data,
            IconProfileStore.profilesKey: .data,
            IconProfileStore.activeKey: .string,
            IconProfileStore.baseKey: .string,
        ]) { current, _ in current }
    }

    static func matches(_ value: Any, _ kind: AppStoreSettingsImport.Kind) -> Bool {
        switch kind {
        case .number: return value is NSNumber
        case .string: return value is String
        case .data: return value is Data
        case .dictionary: return value is [String: Any]
        }
    }

    /// The settings `defaults` holds, ready to write.
    static func export(from defaults: UserDefaults) -> [String: Any] {
        var values: [String: Any] = [versionKey: version]
        for (key, kind) in keys {
            if let value = defaults.object(forKey: key), matches(value, kind) { values[key] = value }
        }
        return values
    }

    /// The known, well-typed settings of a file; nil when it is not a Coulisse settings file.
    static func importable(_ values: [String: Any]) -> [String: Any]? {
        guard values[versionKey] is NSNumber else { return nil }
        let known = keys
        return values.filter { key, value in known[key].map { matches(value, $0) } ?? false }
    }

    /// Replaces the known settings: keys the file lacks go back to their default.
    static func apply(_ values: [String: Any], to defaults: UserDefaults) {
        for key in keys.keys {
            if let value = values[key] { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
    }

    static func data(from defaults: UserDefaults) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: export(from: defaults), format: .xml, options: 0)
    }

    static func values(in data: Data) -> [String: Any]? {
        (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    // MARK: Panels

    static func runExport(from window: NSWindow?) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Coulisse.\(fileExtension)"
        panel.canCreateDirectories = true
        let save = {
            guard let url = panel.url else { return }
            do {
                try data(from: AppDefaults.store).write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        if let window {
            panel.beginSheetModal(for: window) { if $0 == .OK { save() } }
        } else if panel.runModal() == .OK {
            save()
        }
    }

    static func runImport(from window: NSWindow?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        let load = {
            guard let url = panel.url, let raw = try? Data(contentsOf: url),
                  let values = values(in: raw), let settings = importable(values) else {
                let alert = NSAlert()
                alert.messageText = "This file does not hold Coulisse settings.".localized
                alert.runModal()
                return
            }
            let confirm = NSAlert()
            confirm.messageText = "Import these settings?".localized
            confirm.informativeText = "They replace your current settings, profiles and rules. Coulisse then restarts.".localized
            confirm.addButton(withTitle: "Import".localized)
            confirm.addButton(withTitle: "Cancel".localized)
            guard confirm.runModal() == .alertFirstButtonReturn else { return }
            apply(settings, to: AppDefaults.store)
            relaunch()
        }
        if let window {
            panel.beginSheetModal(for: window) { if $0 == .OK { DispatchQueue.main.async(execute: load) } }
        } else if panel.runModal() == .OK {
            load()
        }
    }

    /// Shortcuts, profiles and the engine all read their settings at launch, so a
    /// restart is the one sure way to apply a whole new set.
    static func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
#endif
