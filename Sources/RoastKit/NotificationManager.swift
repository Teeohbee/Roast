import AppKit
import UserNotifications

public struct PRNotification: Equatable, Sendable {
    public let prID: String
    public let url: URL
    public let title: String
    public let body: String
}

@MainActor
public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private static let collapseThreshold = 5
    private let preferences: PreferencesStore
    public var onPRClicked: ((String) -> Void)?

    public init(preferences: PreferencesStore) {
        self.preferences = preferences
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    public func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func deliver(_ events: [PREvent]) {
        guard preferences.notificationsEnabled else { return }
        let notifications = Self.notifications(for: events)
        guard !notifications.isEmpty else { return }

        if notifications.count >= Self.collapseThreshold {
            post(id: "summary", title: "Roast", body: "\(notifications.count) PRs need your attention", userInfo: [:])
            return
        }

        for notification in notifications {
            post(
                id: notification.prID,
                title: notification.title,
                body: notification.body,
                userInfo: ["prID": notification.prID, "url": notification.url.absoluteString]
            )
        }
    }

    nonisolated static func notifications(for events: [PREvent]) -> [PRNotification] {
        var order: [PullRequest] = []
        var primary: [String: PREvent] = [:]
        var comments: [String: Int] = [:]

        for event in events {
            let id = event.pr.id
            if !order.contains(event.pr) { order.append(event.pr) }
            if case .newComments(_, let count) = event {
                comments[id, default: 0] += count
            } else if primary[id] == nil {
                primary[id] = event
            }
        }

        return order.map { pr in
            let commentCount = comments[pr.id] ?? 0
            if let event = primary[pr.id] {
                return notification(for: event, extraComments: commentCount)
            }
            return notification(for: .newComments(pr: pr, count: commentCount))
        }
    }

    nonisolated static func notification(for event: PREvent, extraComments: Int = 0) -> PRNotification {
        let title: String
        let body: String
        let pr: PullRequest

        switch event {
        case .reviewRequested(let requested, let reason):
            pr = requested
            switch reason {
            case .requested:
                title = "Review requested"
                body = "\(pr.author) wants your review on \"\(pr.title)\" (\(pr.repoName))"
            case .teamMemberPR:
                title = "New PR from \(pr.author)"
                body = "\"\(pr.title)\" (\(pr.repoName))"
            case .staleReview:
                title = "New commits since your review"
                body = "\(pr.author) updated \"\(pr.title)\" (\(pr.repoName))"
            }
        case .approved(let approved, let reviewer):
            pr = approved
            title = "PR approved"
            body = "\(reviewer) approved \"\(pr.title)\" (\(pr.repoName))"
        case .changesRequested(let changed, let reviewer):
            pr = changed
            title = "Changes requested"
            body = "\(reviewer) requested changes on \"\(pr.title)\" (\(pr.repoName))"
        case .newComments(let commented, let count):
            pr = commented
            title = "New comments"
            body = "\(count) new comment\(count == 1 ? "" : "s") on \"\(pr.title)\" (\(pr.repoName))"
        }

        let suffix = extraComments > 0 ? " (+\(extraComments) comment\(extraComments == 1 ? "" : "s"))" : ""
        return PRNotification(prID: pr.id, url: pr.url, title: title, body: body + suffix)
    }

    private func post(id: String, title: String, body: String, userInfo: [String: String]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let prID = userInfo["prID"] as? String
        let url = (userInfo["url"] as? String).flatMap(URL.init(string:))
        Task { @MainActor in
            if let url { NSWorkspace.shared.open(url) }
            if let prID { self.onPRClicked?(prID) }
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
