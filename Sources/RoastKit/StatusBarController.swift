import AppKit

@MainActor
public final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private var currentMenu: NSMenu?
    private var categorised: CategorisedPRs = .empty
    private var badgeCount: Int = 0
    private var errorState: Bool = false

    private var newCommentCounts: [String: Int] = [:]
    private var statusText: String = "Not configured"

    private static let menuWidth: CGFloat = 340

    public var onRefresh: (() -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var onPRClicked: ((PullRequest) -> Void)?

    public override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.target = self
        updateIcon()
        rebuildMenu()
    }

    public func update(categorised: CategorisedPRs, badgeCount: Int, newCommentCounts: [String: Int] = [:]) {
        self.categorised = categorised
        self.badgeCount = badgeCount
        self.newCommentCounts = newCommentCounts
        self.errorState = false
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        self.statusText = "Updated \(formatter.string(from: Date()))"
        updateIcon()
        rebuildMenu()
    }

    public func showError(_ message: String = "Check token and team in Settings") {
        self.errorState = true
        self.statusText = message
        updateIcon()
        rebuildMenu()
    }

    // MARK: - Icon

    private func updateIcon() {
        let symbolName: String
        if errorState {
            symbolName = "flame"
        } else if badgeCount > 0 {
            symbolName = "flame.fill"
        } else {
            symbolName = "flame"
        }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium, scale: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Roast")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        statusItem.button?.image = image

        if errorState {
            statusItem.button?.title = " !"
        } else if badgeCount > 0 {
            statusItem.button?.title = " \(badgeCount)"
        } else {
            statusItem.button?.title = ""
        }
    }

    // MARK: - Click

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let menu = currentMenu, let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.minimumWidth = Self.menuWidth

        addSection(to: menu, title: "Needs My Review", prs: categorised.needsMyReview, subtitle: reviewSubtitle)
        addSection(to: menu, title: "My PRs", prs: categorised.myPRs, subtitle: myPRSubtitle)
        addSection(to: menu, title: "New Activity", prs: categorised.newActivity, subtitle: activitySubtitle)

        if categorised.needsMyReview.isEmpty && categorised.myPRs.isEmpty && categorised.newActivity.isEmpty && !errorState {
            let emptyItem = NSMenuItem()
            emptyItem.view = makeEmptyView()
            menu.addItem(emptyItem)
        }

        menu.addItem(.separator())

        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshClicked), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsClicked), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Roast", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.currentMenu = menu
    }

    private func addSection(to menu: NSMenu, title: String, prs: [PullRequest], subtitle: (PullRequest) -> String) {
        guard !prs.isEmpty else { return }

        let header = NSMenuItem(title: "\(title) (\(prs.count))", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for pr in prs {
            let item = NSMenuItem()
            item.view = makePRView(title: pr.title, subtitle: subtitle(pr), pr: pr)
            item.representedObject = pr
            menu.addItem(item)
        }

        menu.addItem(.separator())
    }

    // MARK: - PR Row View

    private func makePRView(title: String, subtitle: String, pr: PullRequest) -> NSView {
        let rowHeight: CGFloat = 44
        let container = PRRowView(frame: NSRect(x: 0, y: 0, width: Self.menuWidth, height: rowHeight))
        container.target = self
        container.action = #selector(prViewClicked(_:))
        container.pr = pr

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
        ])

        return container
    }

    private func makeEmptyView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: Self.menuWidth, height: 36))
        let label = NSTextField(labelWithString: "No PRs need your attention")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    // MARK: - Subtitle Formatters

    private func reviewSubtitle(_ pr: PullRequest) -> String {
        "\(pr.repoName) \u{00b7} \(pr.author) \u{00b7} \(pr.relativeAge)"
    }

    private func myPRSubtitle(_ pr: PullRequest) -> String {
        let verdict: String
        switch pr.overallVerdict {
        case .approved: verdict = "\u{2713} Approved"
        case .changesRequested: verdict = "\u{2717} Changes requested"
        case .pending: verdict = "Pending review"
        case .commented: verdict = "Commented"
        }
        return "\(pr.repoName) \u{00b7} \(verdict) \u{00b7} \(pr.relativeAge)"
    }

    private func activitySubtitle(_ pr: PullRequest) -> String {
        let count = newCommentCounts[pr.id] ?? 0
        let comments = count > 0 ? "\(count) new comment\(count == 1 ? "" : "s") \u{00b7} " : ""
        return "\(pr.repoName) \u{00b7} \(comments)\(pr.relativeAge)"
    }

    // MARK: - Actions

    @objc private func prViewClicked(_ sender: PRRowView) {
        guard let pr = sender.pr else { return }
        currentMenu?.cancelTracking()
        NSWorkspace.shared.open(pr.url)
        onPRClicked?(pr)
    }

    @objc private func refreshClicked() {
        onRefresh?()
    }

    @objc private func settingsClicked() {
        onOpenSettings?()
    }

    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - PRRowView

private class PRRowView: NSView {
    var pr: PullRequest?
    weak var target: AnyObject?
    var action: Selector?
    private var trackingRef: NSTrackingArea?

    private var isHighlighted: Bool = false {
        didSet {
            guard isHighlighted != oldValue else { return }
            subviews.compactMap { $0 as? NSTextField }.forEach { label in
                if isHighlighted {
                    label.textColor = .white
                } else if label.font?.pointSize ?? 0 > 12 {
                    label.textColor = .labelColor
                } else {
                    label.textColor = .secondaryLabelColor
                }
            }
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 4, yRadius: 4).fill()
        }
    }

    override func mouseUp(with event: NSEvent) {
        if let target, let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { ensureTrackingArea() }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        ensureTrackingArea()
    }

    private func ensureTrackingArea() {
        if let old = trackingRef { removeTrackingArea(old) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHighlighted = true
    }

    override func mouseExited(with event: NSEvent) {
        isHighlighted = false
    }
}
