// ~/Projects/Roast/Sources/RoastKit/NotificationManager.swift
import AppKit
import UserNotifications

@MainActor
public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private static let collapseThreshold = 5
    private static let categoryID = "PR_EVENT"
    private static let openAction = "OPEN_PR"

    public override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let openAction = UNNotificationAction(
            identifier: Self.openAction,
            title: "Open PR",
            options: .foreground
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [openAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    public func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func deliver(_ events: [PREvent]) {
        guard !events.isEmpty else { return }

        if events.count >= Self.collapseThreshold {
            deliverSummary(count: events.count)
            return
        }

        for event in events {
            deliverSingle(event)
        }
    }

    private func deliverSingle(_ event: PREvent) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = Self.categoryID

        switch event {
        case .reviewRequested(let pr):
            content.title = "Review requested"
            content.body = "\(pr.author) wants review on \"\(pr.title)\" (\(pr.repoName))"
            content.userInfo = ["url": pr.url.absoluteString]
        case .approved(let pr, let reviewer):
            content.title = "PR approved"
            content.body = "\(reviewer) approved \"\(pr.title)\" (\(pr.repoName))"
            content.userInfo = ["url": pr.url.absoluteString]
        case .changesRequested(let pr, let reviewer):
            content.title = "Changes requested"
            content.body = "\(reviewer) requested changes on \"\(pr.title)\" (\(pr.repoName))"
            content.userInfo = ["url": pr.url.absoluteString]
        case .newComments(let pr, let count):
            content.title = "New comments"
            content.body = "\(count) new comment\(count == 1 ? "" : "s") on \"\(pr.title)\" (\(pr.repoName))"
            content.userInfo = ["url": pr.url.absoluteString]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func deliverSummary(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Roast"
        content.body = "\(count) PRs need your attention"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "summary",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString) {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
        completionHandler()
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
