// ~/Projects/Roast/Sources/RoastKit/PreferencesWindow.swift
import AppKit
import ServiceManagement

@MainActor
public final class PreferencesWindow: NSObject {
    private var window: NSWindow?
    private let preferences: PreferencesStore
    private let notifications: NotificationManager
    public var onSaved: (() -> Void)?

    private var tokenField: NSSecureTextField!
    private var teamField: NSTextField!
    private var intervalStepper: NSStepper!
    private var intervalLabel: NSTextField!
    private var launchCheckbox: NSButton!
    private var notificationsCheckbox: NSButton!
    private var blockedRow: NSStackView!

    public init(preferences: PreferencesStore, notifications: NotificationManager) {
        self.preferences = preferences
        self.notifications = notifications
        super.init()
    }

    public func show() {
        if let existing = window {
            updateBlockedNote()
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Roast Settings"
        w.center()
        w.isReleasedWhenClosed = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Token
        tokenField = NSSecureTextField()
        tokenField.placeholderString = "ghp_..."
        tokenField.stringValue = KeychainStore.loadToken() ?? ""
        stack.addArrangedSubview(labeledRow("GitHub Token", tokenField))

        // Team
        teamField = NSTextField()
        teamField.placeholderString = "org/team-name"
        teamField.stringValue = preferences.teamSlug
        stack.addArrangedSubview(labeledRow("Team", teamField))

        // Poll interval
        let intervalRow = NSStackView()
        intervalRow.orientation = .horizontal
        intervalRow.spacing = 8

        intervalStepper = NSStepper()
        intervalStepper.minValue = 1
        intervalStepper.maxValue = 10
        intervalStepper.integerValue = preferences.pollIntervalMinutes
        intervalStepper.target = self
        intervalStepper.action = #selector(stepperChanged)

        intervalLabel = NSTextField(labelWithString: "\(preferences.pollIntervalMinutes) min")
        intervalLabel.alignment = .right

        intervalRow.addArrangedSubview(intervalStepper)
        intervalRow.addArrangedSubview(intervalLabel)
        stack.addArrangedSubview(labeledRow("Poll Interval", intervalRow))

        // Launch at login
        launchCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
        launchCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        stack.addArrangedSubview(launchCheckbox)

        notificationsCheckbox = NSButton(checkboxWithTitle: "Show notifications", target: nil, action: nil)
        notificationsCheckbox.state = preferences.notificationsEnabled ? .on : .off
        stack.addArrangedSubview(notificationsCheckbox)

        let blockedLabel = NSTextField(labelWithString: "Turned off in System Settings")
        blockedLabel.textColor = .secondaryLabelColor
        let openButton = NSButton(title: "Open", target: self, action: #selector(openNotificationSettings))
        openButton.bezelStyle = .inline
        blockedRow = NSStackView(views: [blockedLabel, openButton])
        blockedRow.orientation = .horizontal
        blockedRow.spacing = 8
        blockedRow.isHidden = true
        stack.addArrangedSubview(blockedRow)

        // Buttons
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        saveButton.keyEquivalent = "\r"

        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(saveButton)
        stack.addArrangedSubview(buttonRow)

        w.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: w.contentView!.topAnchor),
            stack.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: w.contentView!.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: w.contentView!.bottomAnchor),
        ])

        self.window = w
        updateBlockedNote()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func labeledRow(_ label: String, _ control: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        let labelView = NSTextField(labelWithString: label)
        labelView.widthAnchor.constraint(equalToConstant: 100).isActive = true
        labelView.alignment = .right
        row.addArrangedSubview(labelView)
        if let textField = control as? NSTextField {
            textField.widthAnchor.constraint(equalToConstant: 260).isActive = true
        }
        row.addArrangedSubview(control)
        return row
    }

    private func updateBlockedNote() {
        guard preferences.notificationsEnabled else {
            blockedRow.isHidden = true
            return
        }
        Task {
            blockedRow.isHidden = !(await notifications.isBlockedBySystem())
        }
    }

    @objc private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func stepperChanged() {
        intervalLabel.stringValue = "\(intervalStepper.integerValue) min"
    }

    @objc private func saveClicked() {
        let token = tokenField.stringValue
        if !token.isEmpty {
            try? KeychainStore.saveToken(token)
        }

        preferences.teamSlug = teamField.stringValue
        preferences.pollIntervalMinutes = intervalStepper.integerValue
        preferences.notificationsEnabled = notificationsCheckbox.state == .on

        if launchCheckbox.state == .on {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }

        window?.close()
        onSaved?()
    }

    @objc private func cancelClicked() {
        window?.close()
    }
}
