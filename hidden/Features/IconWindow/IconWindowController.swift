//
//  IconWindowController.swift
//  Coulisse
//
//  Copyright © 2026 Lucas Minelli. MIT license.
//

#if HIDDENBAR_NATIVE_VISIBILITY
import AppKit

/// What the icon window asks of the rest of the app.
struct IconWindowHost {
    var environment: () -> PaletteEnvironment
    /// The arrow's window frame in screen coordinates, nil when it is not on screen.
    var arrowFrame: () -> CGRect?
    /// Allows the app, presses its icon and re-hides it when its menu closes.
    var open: (String, @escaping (PaletteOpenResult) -> Void) -> Void
    var move: (MenuBarSection, String) -> Void
    /// Expands the bar for real, as a click did before Coulisse.
    var expandBar: () -> Void
    var openAccessibilitySettings: () -> Void
    var openSettings: () -> Void
}

/// The icon window: a small panel under the arrow that shows the hidden apps as
/// a grid, so a full menu bar (a notch, a narrow display) never pushes them into
/// macOS's « button. A click opens the app's own menu, as the palette does.
final class IconWindowController {
    /// A click on the arrow right after the window closed by losing focus is the
    /// same click that closed it: it must not open the window again.
    static let reopenGuard: TimeInterval = 0.35

    private let host: IconWindowHost
    private let catalog: MenuBarItemCatalog
    private let screens: () -> [PaletteScreen]
    private let pointer: () -> CGPoint
    private let now: () -> TimeInterval
    private let ordersPanelFront: Bool
    private let notifications: NotificationCenter

    private(set) var content: IconWindowContent = .nothingHidden
    private(set) var openingBundle: String?
    private(set) var failure: String?
    private(set) var panel: PalettePanel?
    private(set) var contentView: IconWindowView?
    private var catalogObserver: NSObjectProtocol?
    private var closedAt: TimeInterval = -.infinity

    init(host: IconWindowHost,
         catalog: MenuBarItemCatalog = .shared,
         screens: @escaping () -> [PaletteScreen] = PaletteController.liveScreens,
         pointer: @escaping () -> CGPoint = { NSEvent.mouseLocation },
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         notifications: NotificationCenter = .default,
         ordersPanelFront: Bool = true) {
        self.host = host
        self.catalog = catalog
        self.screens = screens
        self.pointer = pointer
        self.now = now
        self.notifications = notifications
        self.ordersPanelFront = ordersPanelFront
    }

    deinit {
        catalogObserver.map(notifications.removeObserver)
    }

    var isVisible: Bool { panel != nil }

    /// The window closed a moment ago, most likely from the click now arriving.
    var justClosed: Bool { now() - closedAt < Self.reopenGuard }

    // MARK: Showing

    func toggle() {
        if isVisible { close() } else if !justClosed { show() }
    }

    func show() {
        close()
        closedAt = -.infinity
        openingBundle = nil
        failure = nil
        refreshContent()
        let view = IconWindowView()
        view.onTileClick = { [weak self] in self?.open($0) }
        view.onMove = { [weak self] section, bundle in self?.move(section, bundle) }
        view.onExpand = { [weak self] in
            self?.close()
            self?.host.expandBar()
        }
        view.onSettings = { [weak self] in
            self?.close()
            self?.host.openSettings()
        }
        view.onAccessibility = { [weak self] in
            self?.close()
            self?.host.openAccessibilitySettings()
        }
        let panel = PalettePanel(content: view)
        panel.onKey = { [weak self] action in
            if action == .close { self?.close() }
        }
        panel.onResignKey = { [weak self] in self?.close() }
        self.panel = panel
        contentView = view
        render()
        if ordersPanelFront { panel.makeKeyAndOrderFront(nil) }
        catalogObserver = notifications.addObserver(forName: .menuBarCatalogChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refreshContent()
            self?.render()
        }
    }

    func close() {
        catalogObserver.map(notifications.removeObserver)
        catalogObserver = nil
        guard let closing = panel else { return }
        panel = nil
        contentView = nil
        openingBundle = nil
        closedAt = now()
        // Detach first: ordering out resigns key, which would call back in.
        closing.onResignKey = nil
        if ordersPanelFront { closing.orderOut(nil) }
    }

    // MARK: Actions

    /// A tile was clicked: open that app's own menu.
    func open(_ bundle: String) {
        guard openingBundle == nil, isVisible else { return }
        openingBundle = bundle
        failure = nil
        render()
        let name = catalog.entry(for: bundle)?.name ?? bundle
        host.open(bundle) { [weak self] result in
            self?.opened(name: name, result)
        }
    }

    private func opened(name: String, _ result: PaletteOpenResult) {
        openingBundle = nil
        switch result {
        case .opened:
            close()
        case .noItem:
            failure = String(format: "macOS found no room for %@ in the menu bar. Expand the bar, or move an icon you rarely use to Always hidden.".localized, name)
            render()
        case .noPress:
            failure = String(format: "%@ can't be opened from here".localized, name)
            render()
        case .sensitive, .unavailable:
            refreshContent()
            render()
        }
    }

    private func move(_ section: MenuBarSection, _ bundle: String) {
        host.move(section, bundle)
        refreshContent()
        render()
    }

    // MARK: Drawing

    private func refreshContent() {
        content = IconWindowModel.content(candidates: PaletteController.candidates(from: catalog.entries),
                                          environment: host.environment())
    }

    private func render() {
        guard let panel, let contentView else { return }
        contentView.apply(content: content, openingBundle: openingBundle, failure: failure,
                          pinsSections: host.environment().pinsSections,
                          icon: { [catalog] in catalog.entry(for: $0)?.icon })
        contentView.layoutSubtreeIfNeeded()
        let size = contentView.fittingSize
        let frame = PalettePlacement.frame(size: size, arrow: host.arrowFrame(), pointer: pointer(), screens: screens())
        panel.setFrame(frame ?? NSRect(origin: panel.frame.origin, size: size), display: true)
    }
}

// MARK: - Views

/// The window's content: a header, the grid of hidden apps by section, and a line
/// that says why the last click opened nothing.
final class IconWindowView: NSView {
    static let tileSize = NSSize(width: 64, height: 66)
    static let tileSpacing: CGFloat = 4
    static let padding: CGFloat = 12
    static let minWidth: CGFloat = 300

    var onTileClick: ((String) -> Void)?
    var onMove: ((MenuBarSection, String) -> Void)?
    var onExpand: (() -> Void)?
    var onSettings: (() -> Void)?
    var onAccessibility: (() -> Void)?

    private let stack = NSStackView()
    private var widthConstraint: NSLayoutConstraint?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.cgColor

        let blur = NSVisualEffectView()
        blur.material = .popover
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 10, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        let width = widthAnchor.constraint(equalToConstant: Self.minWidth)
        widthConstraint = width
        NSLayoutConstraint.activate([
            width,
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    static func width(columns: Int) -> CGFloat {
        let grid = CGFloat(columns) * tileSize.width + CGFloat(max(columns - 1, 0)) * tileSpacing + 2 * padding
        return max(minWidth, grid)
    }

    func apply(content: IconWindowContent, openingBundle: String?, failure: String?, pinsSections: Bool,
               icon: (String) -> NSImage?) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let width = Self.width(columns: IconWindowModel.columns(for: content))
        widthConstraint?.constant = width
        let inner = width - 2 * Self.padding

        add(header(count: content.tileCount, showsExpand: content.tileCount > 0), width: inner)
        switch content {
        case .tiles(let hidden, let alwaysHidden):
            let both = !hidden.isEmpty && !alwaysHidden.isEmpty
            for (section, tiles) in [(MenuBarSection.hidden, hidden), (.alwaysHidden, alwaysHidden)] where !tiles.isEmpty {
                if both { add(sectionLabel(PaletteContentView.sectionTitle(section)), width: inner) }
                for row in IconWindowModel.rows(tiles) {
                    let views = row.map { tile -> NSView in
                        let view = IconTileView(tile: tile, icon: icon(tile.bundleIdentifier),
                                                opening: tile.bundleIdentifier == openingBundle,
                                                dimmed: openingBundle != nil && tile.bundleIdentifier != openingBundle,
                                                pinsSections: pinsSections)
                        view.onClick = { [weak self] in self?.onTileClick?(tile.bundleIdentifier) }
                        view.onMove = { [weak self] in self?.onMove?($0, tile.bundleIdentifier) }
                        return view
                    }
                    let line = NSStackView(views: views)
                    line.spacing = Self.tileSpacing
                    stack.addArrangedSubview(line)
                }
            }
            if let failure {
                add(wrapping(failure, color: .systemOrange), width: inner)
            } else {
                add(wrapping("Click an icon to open its menu.".localized, color: .secondaryLabelColor), width: inner)
            }
        case .nothingHidden:
            add(wrapping("Nothing is hidden right now".localized, color: .secondaryLabelColor), width: inner)
        case .engineUnavailable:
            add(wrapping("Coulisse is not hiding icons right now".localized, color: .secondaryLabelColor), width: inner)
        case .accessibilityOff:
            add(wrapping("Coulisse needs Accessibility access".localized, color: .secondaryLabelColor), width: inner)
            let button = NSButton(title: "Open System Settings".localized, target: self, action: #selector(accessibilityPressed))
            button.bezelStyle = .rounded
            button.controlSize = .small
            stack.addArrangedSubview(button)
        }
    }

    private func add(_ view: NSView, width: CGFloat) {
        stack.addArrangedSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
    }

    private func header(count: Int, showsExpand: Bool) -> NSView {
        let title = NSTextField(labelWithString: "Hidden icons".localized)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let badge = NSTextField(labelWithString: count > 0 ? "\(count)" : "")
        badge.font = .systemFont(ofSize: 12, weight: .medium)
        badge.textColor = .secondaryLabelColor
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        var views: [NSView] = [title, badge, spacer]
        if showsExpand {
            views.append(Self.iconButton("rectangle.expand.horizontal", tip: "Expand the bar".localized,
                                         target: self, action: #selector(expandPressed)))
        }
        views.append(Self.iconButton("gearshape", tip: "Settings…".localized, target: self, action: #selector(settingsPressed)))
        let row = NSStackView(views: views)
        row.spacing = 6
        row.alignment = .centerY
        return row
    }

    private static func iconButton(_ symbol: String, tip: String, target: AnyObject, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip) ?? NSImage()
        let button = NSButton(image: image, target: target, action: action)
        button.isBordered = false
        button.bezelStyle = .accessoryBarAction
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = tip
        button.setAccessibilityLabel(tip)
        return button
    }

    private func sectionLabel(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text.uppercased())
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func wrapping(_ text: String, color: NSColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = color
        return label
    }

    @objc private func expandPressed() { onExpand?() }
    @objc private func settingsPressed() { onSettings?() }
    @objc private func accessibilityPressed() { onAccessibility?() }
}

/// One hidden app: its icon and name. Click opens its menu; right-click moves it
/// to another section.
final class IconTileView: NSView {
    var onClick: (() -> Void)?
    var onMove: ((MenuBarSection) -> Void)?

    private let tile: IconWindowTile
    private let pinsSections: Bool
    private var hovering = false {
        didSet { paint() }
    }

    init(tile: IconWindowTile, icon: NSImage?, opening: Bool, dimmed: Bool, pinsSections: Bool) {
        self.tile = tile
        self.pinsSections = pinsSections
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 10
        alphaValue = dimmed ? 0.45 : 1

        let image = NSImageView(image: icon ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage())
        image.imageScaling = .scaleProportionallyUpOrDown
        image.translatesAutoresizingMaskIntoConstraints = false
        image.alphaValue = opening ? 0.5 : 1
        let name = NSTextField(labelWithString: opening ? "Opening…".localized : tile.name)
        name.font = .systemFont(ofSize: 10.5)
        name.alignment = .center
        name.lineBreakMode = .byTruncatingTail
        name.maximumNumberOfLines = 1
        name.translatesAutoresizingMaskIntoConstraints = false
        addSubview(image)
        addSubview(name)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: IconWindowView.tileSize.width),
            heightAnchor.constraint(equalToConstant: IconWindowView.tileSize.height),
            image.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            image.centerXAnchor.constraint(equalTo: centerXAnchor),
            image.widthAnchor.constraint(equalToConstant: 32),
            image.heightAnchor.constraint(equalToConstant: 32),
            name.topAnchor.constraint(equalTo: image.bottomAnchor, constant: 5),
            name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            name.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
        ])
        toolTip = tile.name
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(tile.name)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        paint()
    }

    private func paint() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = hovering ? NSColor.labelColor.withAlphaComponent(0.1).cgColor : nil
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        onClick?()
    }

    override func mouseDown(with event: NSEvent) {
        // Handled on mouse up, like a button: a press that slides off does nothing.
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard pinsSections else { return nil }
        let menu = NSMenu()
        for (section, title) in [(MenuBarSection.visible, "Show"), (.hidden, "Hide"), (.alwaysHidden, "Always hide")] {
            let item = NSMenuItem(title: title.localized, action: #selector(movePicked(_:)), keyEquivalent: "")
            item.target = self
            item.tag = section.rawValue
            item.state = section == tile.section ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func movePicked(_ sender: NSMenuItem) {
        guard let section = MenuBarSection(rawValue: sender.tag), section != tile.section else { return }
        onMove?(section)
    }
}
#endif
