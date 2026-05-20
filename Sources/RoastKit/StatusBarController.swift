// ~/Projects/Roast/Sources/RoastKit/StatusBarController.swift
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

        addSection(to: menu, title: "Needs My Review", prs: categorised.needsMyReview, formatter: reviewFormatter)
        addSection(to: menu, title: "My PRs", prs: categorised.myPRs, formatter: myPRFormatter)
        addSection(to: menu, title: "New Activity", prs: categorised.newActivity, formatter: activityFormatter)

        if !categorised.needsMyReview.isEmpty || !categorised.myPRs.isEmpty || !categorised.newActivity.isEmpty {
            menu.addItem(.separator())
        }

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

    private func addSection(to menu: NSMenu, title: String, prs: [PullRequest], formatter: (PullRequest) -> String) {
        guard !prs.isEmpty else { return }

        let header = NSMenuItem(title: "\(title) (\(prs.count))", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for pr in prs {
            let item = NSMenuItem(title: formatter(pr), action: #selector(prClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pr
            menu.addItem(item)
        }

        menu.addItem(.separator())
    }

    private func reviewFormatter(_ pr: PullRequest) -> String {
        "  \(pr.title)    \(pr.repoName)    \(pr.relativeAge)"
    }

    private func myPRFormatter(_ pr: PullRequest) -> String {
        let verdict: String
        switch pr.overallVerdict {
        case .approved: verdict = "\u{2713} Approved"
        case .changesRequested: verdict = "\u{2717} Changes requested"
        case .pending: verdict = "\u{23F3} Pending review"
        case .commented: verdict = "\u{1F4AC} Commented"
        }
        return "  \(pr.title)    \(verdict)    \(pr.repoName)    \(pr.relativeAge)"
    }

    private func activityFormatter(_ pr: PullRequest) -> String {
        let count = newCommentCounts[pr.id] ?? 0
        let label = count > 0 ? "\u{1F4AC} \(count) new" : ""
        return "  \(pr.title)    \(label)    \(pr.repoName)    \(pr.relativeAge)"
    }

    // MARK: - Actions

    @objc private func prClicked(_ sender: NSMenuItem) {
        guard let pr = sender.representedObject as? PullRequest else { return }
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
