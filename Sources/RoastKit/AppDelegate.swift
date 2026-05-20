import AppKit
import ServiceManagement

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    private var preferences: PreferencesStore!
    private var statusBar: StatusBarController!
    private var notifications: NotificationManager!
    private var poller: Poller!
    private var preferencesWindow: PreferencesWindow!

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()

        preferences = PreferencesStore()
        statusBar = StatusBarController()
        notifications = NotificationManager()
        poller = Poller(
            preferences: preferences,
            statusBar: statusBar,
            notifications: notifications
        )
        preferencesWindow = PreferencesWindow(preferences: preferences)

        statusBar.onRefresh = { [weak self] in
            self?.poller.poll()
        }

        statusBar.onOpenSettings = { [weak self] in
            self?.preferencesWindow.show()
        }

        statusBar.onPRClicked = { [weak self] pr in
            self?.poller.markSeen(pr)
        }

        preferencesWindow.onSaved = { [weak self] in
            self?.poller.resetClient()
            self?.poller.scheduleTimer()
            self?.poller.poll()
        }

        notifications.requestPermission()

        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poller.poll()
            }
        }

        if KeychainStore.loadToken() == nil || preferences.teamSlug.isEmpty {
            preferencesWindow.show()
        }

        poller.start()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }
}
