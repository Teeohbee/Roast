import AppKit

@MainActor
public final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private var categorised: CategorisedPRs = .empty
    private var merged: [MergedPullRequest] = []
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
        updateIcon()
        rebuildMenu()
    }

    public func update(categorised: CategorisedPRs, merged: [MergedPullRequest], badgeCount: Int, prStore: PRStore) {
        self.categorised = categorised
        self.merged = merged
        self.badgeCount = badgeCount
        self.prStore = prStore
        self.errorState = false
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        self.statusText = "Updated \(formatter.string(from: Date()))"
        updateIcon()
        rebuildMenu()
    }

    public func refresh(badgeCount: Int) {
        self.badgeCount = badgeCount
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

        if !merged.isEmpty {
            menu.addItem(.separator())
            let mergedItem = NSMenuItem(title: "Recently Merged", action: nil, keyEquivalent: "")
            mergedItem.submenu = mergedMenu()
            menu.addItem(mergedItem)
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

        self.statusItem.menu = menu
    }

    private func addSection(to menu: NSMenu, title: String, prs: [PullRequest], subtitle: (PullRequest) -> NSAttributedString) {
        guard !prs.isEmpty else { return }

        let header = NSMenuItem(title: "\(title) (\(prs.count))", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let sorted = prs.sorted { $0.createdAt > $1.createdAt }
        for pr in sorted {
            let item = NSMenuItem()
            let row = prAttributedTitle(pr: pr, subtitle: subtitle(pr))
            item.attributedTitle = row
            item.action = #selector(prClicked(_:))
            item.target = self
            item.representedObject = pr
            item.keyEquivalentModifierMask = []
            menu.addItem(item)
            if let ticket = pr.jiraTicket {
                addAlternate(to: menu, row: row, action: "Open \(ticket) in Jira", modifier: .command, selector: #selector(jiraClicked(_:)), object: pr)
            }
            addAlternate(to: menu, row: row, action: "Copy link", modifier: .option, selector: #selector(copyLinkClicked(_:)), object: pr.url)
        }

        menu.addItem(.separator())
    }

    private func addAlternate(to menu: NSMenu, row: NSAttributedString, action: String, modifier: NSEvent.ModifierFlags, selector: Selector, object: Any?) {
        let item = NSMenuItem(title: "", action: selector, keyEquivalent: "")
        let text = NSMutableAttributedString(attributedString: row)
        text.append(sep())
        text.append(coloured(action, .controlAccentColor))
        item.attributedTitle = text
        item.keyEquivalentModifierMask = modifier
        item.isAlternate = true
        item.target = self
        item.representedObject = object
        menu.addItem(item)
    }

    private func mergedMenu() -> NSMenu {
        let menu = NSMenu()
        for pr in merged {
            let item = NSMenuItem()
            let title = NSMutableAttributedString(string: pr.title, attributes: [
                .font: Self.titleFont,
                .foregroundColor: NSColor.labelColor,
            ])
            title.append(NSAttributedString(string: "\n"))
            title.append(sub(pr.repoName))
            title.append(sep())
            title.append(sub("#\(pr.number)"))
            title.append(sep())
            title.append(sub("merged \(pr.relativeAge) ago"))
            item.attributedTitle = title
            item.action = #selector(mergedClicked(_:))
            item.target = self
            item.representedObject = pr
            item.keyEquivalentModifierMask = []
            menu.addItem(item)
            if let ticket = jiraTicket(in: pr.title) {
                addAlternate(to: menu, row: title, action: "Open \(ticket) in Jira", modifier: .command, selector: #selector(jiraClicked(_:)), object: pr.jiraURL)
            }
            addAlternate(to: menu, row: title, action: "Copy link", modifier: .option, selector: #selector(copyLinkClicked(_:)), object: pr.url)
        }
        return menu
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
        NSWorkspace.shared.open(pr.url)
        onPRClicked?(pr)
    }

    @objc private func copyLinkClicked(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    @objc private func jiraClicked(_ sender: NSMenuItem) {
        if let pr = sender.representedObject as? PullRequest, let url = pr.jiraURL {
            NSWorkspace.shared.open(url)
            onPRClicked?(pr)
        } else if let url = sender.representedObject as? URL {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func mergedClicked(_ sender: NSMenuItem) {
        guard let pr = sender.representedObject as? MergedPullRequest else { return }
        NSWorkspace.shared.open(pr.url)
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
