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

    private static let menuWidth: CGFloat = 420

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

        addSection(to: menu, icon: "\u{1F440}", title: "Needs My Review", prs: categorised.needsMyReview, badgeColour: .systemRed, subtitle: reviewSubtitle)
        addSection(to: menu, icon: "\u{1F4E4}", title: "My PRs", prs: categorised.myPRs, badgeColour: .systemGray, subtitle: myPRSubtitle)
        addSection(to: menu, icon: "\u{1F4AC}", title: "New Activity", prs: categorised.newActivity, badgeColour: .systemBlue, subtitle: activitySubtitle)

        if !categorised.drafts.isEmpty {
            addDraftsSection(to: menu)
        }

        if categorised.needsMyReview.isEmpty && categorised.myPRs.isEmpty && categorised.newActivity.isEmpty && categorised.drafts.isEmpty && !errorState {
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

    private func addSection(to menu: NSMenu, icon: String, title: String, prs: [PullRequest], badgeColour: NSColor, subtitle: (PullRequest) -> NSAttributedString) {
        guard !prs.isEmpty else { return }

        let headerItem = NSMenuItem()
        headerItem.view = makeSectionHeader(icon: icon, title: title, count: prs.count, badgeColour: badgeColour)
        menu.addItem(headerItem)

        let sorted = prs.sorted { $0.createdAt > $1.createdAt }
        for pr in sorted {
            let item = NSMenuItem()
            item.view = makePRView(pr: pr, subtitleAttr: subtitle(pr))
            item.representedObject = pr
            menu.addItem(item)
        }

        menu.addItem(.separator())
    }

    private func addDraftsSection(to menu: NSMenu) {
        let draftsItem = NSMenuItem(title: "Drafts (\(categorised.drafts.count))", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.minimumWidth = Self.menuWidth

        let sorted = categorised.drafts.sorted { $0.createdAt > $1.createdAt }
        for pr in sorted {
            let item = NSMenuItem()
            item.view = makePRView(pr: pr, subtitleAttr: reviewSubtitle(pr))
            item.representedObject = pr
            submenu.addItem(item)
        }

        draftsItem.submenu = submenu

        let headerItem = NSMenuItem()
        headerItem.view = makeDraftsHeader(count: categorised.drafts.count)
        headerItem.submenu = submenu
        menu.addItem(headerItem)
        menu.addItem(.separator())
    }

    // MARK: - Section Header

    private func makeSectionHeader(icon: String, title: String, count: Int, badgeColour: NSColor) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: Self.menuWidth, height: 28))

        let iconLabel = NSTextField(labelWithString: icon)
        iconLabel.font = .systemFont(ofSize: 12)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        let badgeLabel = NSTextField(labelWithString: "\(count)")
        badgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.alignment = .center
        badgeLabel.backgroundColor = badgeColour
        badgeLabel.drawsBackground = true
        badgeLabel.isBezeled = false
        badgeLabel.wantsLayer = true
        badgeLabel.layer?.cornerRadius = 7

        for v in [iconLabel, titleLabel, badgeLabel] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(v)
        }

        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            badgeLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            badgeLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            badgeLabel.heightAnchor.constraint(equalToConstant: 16),
        ])

        return container
    }

    private func makeDraftsHeader(count: Int) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: Self.menuWidth, height: 26))

        let arrow = NSTextField(labelWithString: "\u{25B6}")
        arrow.font = .systemFont(ofSize: 9)
        arrow.textColor = .systemOrange

        let titleLabel = NSTextField(labelWithString: "Drafts")
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor

        let badgeLabel = NSTextField(labelWithString: "\(count)")
        badgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textColor = .systemOrange
        badgeLabel.alignment = .center
        badgeLabel.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.15)
        badgeLabel.drawsBackground = true
        badgeLabel.isBezeled = false
        badgeLabel.wantsLayer = true
        badgeLabel.layer?.cornerRadius = 7

        for v in [arrow, titleLabel, badgeLabel] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(v)
        }

        NSLayoutConstraint.activate([
            arrow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 22),
            arrow.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: arrow.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            badgeLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            badgeLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            badgeLabel.heightAnchor.constraint(equalToConstant: 16),
        ])

        return container
    }

    // MARK: - PR Row View

    private func makePRView(pr: PullRequest, subtitleAttr: NSAttributedString) -> NSView {
        let rowHeight: CGFloat = 44
        let container = PRRowView(frame: NSRect(x: 0, y: 0, width: Self.menuWidth, height: rowHeight))
        container.target = self
        container.action = #selector(prViewClicked(_:))
        container.pr = pr

        let titleLabel = NSTextField(labelWithString: pr.title)
        titleLabel.font = pr.isDraft
            ? NSFont.systemFont(ofSize: 13, weight: .regular)
            : NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = pr.isDraft ? .secondaryLabelColor : .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        let subtitleLabel = NSTextField(labelWithAttributedString: subtitleAttr)
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

    private static let subtitleFont = NSFont.systemFont(ofSize: 11)
    private static let subtitleAttrs: [NSAttributedString.Key: Any] = [
        .font: subtitleFont,
        .foregroundColor: NSColor.secondaryLabelColor,
    ]

    private func styledSubtitle(_ parts: [SubtitlePart]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for part in parts {
            switch part {
            case .repoPill(let name):
                let pillAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .backgroundColor: NSColor.quaternaryLabelColor,
                ]
                result.append(NSAttributedString(string: " \(name) ", attributes: pillAttrs))
                result.append(NSAttributedString(string: " ", attributes: Self.subtitleAttrs))
            case .ciDot(let status):
                let colour: NSColor
                switch status {
                case .success: colour = .systemGreen
                case .failure, .error: colour = .systemRed
                case .pending: colour = .systemYellow
                case .expected, .unknown: colour = .tertiaryLabelColor
                }
                let dotAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: colour,
                ]
                result.append(NSAttributedString(string: "\u{25CF} ", attributes: dotAttrs))
            case .text(let text):
                result.append(NSAttributedString(string: text, attributes: Self.subtitleAttrs))
            case .separator:
                result.append(NSAttributedString(string: " \u{00b7} ", attributes: Self.subtitleAttrs))
            case .coloured(let text, let colour):
                var attrs = Self.subtitleAttrs
                attrs[.foregroundColor] = colour
                result.append(NSAttributedString(string: text, attributes: attrs))
            case .age(let pr):
                let ageText = pr.relativeAge
                let colour = ageColour(pr)
                var attrs = Self.subtitleAttrs
                attrs[.foregroundColor] = colour
                result.append(NSAttributedString(string: ageText, attributes: attrs))
            }
        }
        return result
    }

    private func ageColour(_ pr: PullRequest) -> NSColor {
        let days = Int(Date().timeIntervalSince(pr.createdAt)) / 86400
        if days > 7 { return .systemRed }
        if days > 1 { return .systemOrange }
        return .secondaryLabelColor
    }

    private enum SubtitlePart {
        case repoPill(String)
        case ciDot(CIStatus)
        case text(String)
        case separator
        case coloured(String, NSColor)
        case age(PullRequest)
    }

    private func reviewSubtitle(_ pr: PullRequest) -> NSAttributedString {
        var parts: [SubtitlePart] = [
            .repoPill(pr.repoName),
            .ciDot(pr.ciStatus),
            .text("#\(pr.number)"),
            .separator,
            .text(pr.author),
            .separator,
            .age(pr),
        ]
        if pr.isDraft {
            parts.insert(.coloured("Draft", .systemOrange), at: 0)
            parts.insert(.separator, at: 1)
        }
        return styledSubtitle(parts)
    }

    private func myPRSubtitle(_ pr: PullRequest) -> NSAttributedString {
        var parts: [SubtitlePart] = [
            .repoPill(pr.repoName),
            .ciDot(pr.ciStatus),
            .text("#\(pr.number)"),
            .separator,
        ]
        if pr.isDraft {
            parts.append(.coloured("Draft", .systemOrange))
            parts.append(.separator)
        }
        switch pr.overallVerdict {
        case .approved:
            parts.append(.coloured("\u{2713} Approved", .systemGreen))
        case .changesRequested:
            parts.append(.coloured("\u{2717} Changes requested", .systemRed))
        case .pending:
            parts.append(.text("Pending review"))
        case .commented:
            parts.append(.text("Commented"))
        }
        parts.append(.separator)
        parts.append(.age(pr))
        return styledSubtitle(parts)
    }

    private func activitySubtitle(_ pr: PullRequest) -> NSAttributedString {
        var parts: [SubtitlePart] = [
            .repoPill(pr.repoName),
            .ciDot(pr.ciStatus),
            .text("#\(pr.number)"),
        ]
        let count = newCommentCounts[pr.id] ?? 0
        if count > 0 {
            parts.append(.separator)
            parts.append(.coloured("\(count) new comment\(count == 1 ? "" : "s")", .systemBlue))
        }
        parts.append(.separator)
        parts.append(.age(pr))
        return styledSubtitle(parts)
    }

    // MARK: - Actions

    @objc private func prViewClicked(_ sender: PRRowView) {
        guard let pr = sender.pr else { return }
        currentMenu?.cancelTracking()

        let cmdHeld = NSEvent.modifierFlags.contains(.command)
        if cmdHeld, let jiraURL = pr.jiraURL {
            NSWorkspace.shared.open(jiraURL)
        } else {
            NSWorkspace.shared.open(pr.url)
        }
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
                    label.textColor = (pr?.isDraft == true) ? .secondaryLabelColor : .labelColor
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
