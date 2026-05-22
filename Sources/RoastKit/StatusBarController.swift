import AppKit

@MainActor
public final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private var currentMenu: NSMenu?
    private var categorised: CategorisedPRs = .empty
    private var badgeCount: Int = 0
    private var errorState: Bool = false
    private var prStore: PRStore?

    private var statusText: String = "Not configured"

    public var onRefresh: (() -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var onPRClicked: ((PullRequest) -> Void)?

    public override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.behavior = .removalAllowed
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.target = self
        updateIcon()
        rebuildMenu()
    }

    public func update(categorised: CategorisedPRs, badgeCount: Int, prStore: PRStore) {
        self.categorised = categorised
        self.badgeCount = badgeCount
        self.prStore = prStore
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

        let label: String
        if errorState {
            label = "Roast - error"
        } else if badgeCount > 0 {
            label = "Roast - \(badgeCount) items need attention"
        } else {
            label = "Roast - no items"
        }
        statusItem.button?.setAccessibilityLabel(label)
        statusItem.button?.toolTip = label
    }

    // MARK: - Click

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let menu = currentMenu, let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let menu = NSMenu()

        addSection(to: menu, title: "Needs My Review", prs: categorised.needsMyReview, subtitle: reviewSubtitle)
        addSection(to: menu, title: "My PRs", prs: categorised.myPRs, subtitle: myPRSubtitle)

        if categorised.needsMyReview.isEmpty && categorised.myPRs.isEmpty && !errorState {
            let emptyItem = NSMenuItem(title: "No PRs need your attention", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
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

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let versionItem = NSMenuItem(title: "Roast \(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Roast", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.currentMenu = menu
    }

    private func addSection(to menu: NSMenu, title: String, prs: [PullRequest], subtitle: (PullRequest) -> NSAttributedString) {
        guard !prs.isEmpty else { return }

        let header = NSMenuItem(title: "\(title) (\(prs.count))", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let sorted = prs.sorted { $0.createdAt > $1.createdAt }
        for pr in sorted {
            let item = NSMenuItem()
            item.attributedTitle = prAttributedTitle(pr: pr, subtitle: subtitle(pr))
            item.action = #selector(prClicked(_:))
            item.target = self
            item.representedObject = pr
            menu.addItem(item)
        }

        menu.addItem(.separator())
    }

    // MARK: - Attributed Titles

    private static let titleFont = NSFont.systemFont(ofSize: 13, weight: .medium)
    private static let titleDraftFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    private static let subtitleFont = NSFont.systemFont(ofSize: 11)

    private func prAttributedTitle(pr: PullRequest, subtitle: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: pr.isDraft ? Self.titleDraftFont : Self.titleFont,
            .foregroundColor: pr.isDraft ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]
        result.append(NSAttributedString(string: pr.title, attributes: titleAttrs))
        result.append(NSAttributedString(string: "\n"))
        result.append(subtitle)

        return result
    }

    private static let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subtitleFont,
        .foregroundColor: NSColor.secondaryLabelColor,
    ]

    private func ciDotString(_ status: CIStatus) -> NSAttributedString {
        let colour: NSColor
        switch status {
        case .success: colour = .systemGreen
        case .failure, .error: colour = .systemRed
        case .pending: colour = .systemYellow
        case .expected, .unknown: colour = .tertiaryLabelColor
        }
        return NSAttributedString(string: "\u{25CF}", attributes: [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: colour,
        ])
    }

    private func sep() -> NSAttributedString {
        NSAttributedString(string: " \u{00b7} ", attributes: Self.subAttrs)
    }

    private func sub(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: Self.subAttrs)
    }

    private func coloured(_ text: String, _ colour: NSColor) -> NSAttributedString {
        var attrs = Self.subAttrs
        attrs[.foregroundColor] = colour
        return NSAttributedString(string: text, attributes: attrs)
    }

    private func newCommentsString(_ pr: PullRequest) -> NSAttributedString? {
        guard let store = prStore else { return nil }
        let count = store.newCommentCount(for: pr)
        guard count > 0 else { return nil }
        let result = NSMutableAttributedString()
        result.append(sep())
        result.append(coloured("\(count) new comment\(count == 1 ? "" : "s")", .systemBlue))
        return result
    }

    private func reviewSubtitle(_ pr: PullRequest) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if pr.isDraft { result.append(coloured("Draft", .systemOrange)); result.append(sep()) }
        result.append(sub(pr.repoName))
        result.append(sub(" "))
        result.append(ciDotString(pr.ciStatus))
        result.append(sep())
        result.append(sub("#\(pr.number)"))
        result.append(sep())
        result.append(sub(pr.author))
        result.append(sep())
        result.append(sub(pr.relativeAge))
        if let comments = newCommentsString(pr) { result.append(comments) }
        if let store = prStore, store.isStaleReview(pr) {
            result.append(sep())
            result.append(sub("\u{21bb} Review stale"))
        }
        return result
    }

    private func myPRSubtitle(_ pr: PullRequest) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if pr.isDraft { result.append(coloured("Draft", .systemOrange)); result.append(sep()) }
        result.append(sub(pr.repoName))
        result.append(sub(" "))
        result.append(ciDotString(pr.ciStatus))
        result.append(sep())
        result.append(sub("#\(pr.number)"))
        result.append(sep())
        switch pr.overallVerdict {
        case .approved: result.append(coloured("\u{2713} Approved", .systemGreen))
        case .changesRequested: result.append(coloured("\u{2717} Changes requested", .systemRed))
        case .pending: result.append(sub("Pending review"))
        case .commented: result.append(sub("Commented"))
        }
        result.append(sep())
        result.append(sub(pr.relativeAge))
        if let comments = newCommentsString(pr) { result.append(comments) }
        return result
    }

    // MARK: - Actions

    @objc private func prClicked(_ sender: NSMenuItem) {
        guard let pr = sender.representedObject as? PullRequest else { return }

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
