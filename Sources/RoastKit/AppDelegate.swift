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

        poller.start()
    }
}
