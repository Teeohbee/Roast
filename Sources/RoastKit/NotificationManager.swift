import AppKit
import UserNotifications

public struct PRNotification: Equatable, Sendable {
    public let prID: String
    public let url: URL
    public let title: String
    public let subtitle: String
    public let body: String
    public let threadID: String
    public let actor: String
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

    public func isBlockedBySystem() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    public func deliver(_ events: [PREvent]) {
        guard preferences.notificationsEnabled else { return }
        let notifications = Self.notifications(for: events)
        guard !notifications.isEmpty else { return }

        if notifications.count >= Self.collapseThreshold {
            let content = UNMutableNotificationContent()
            content.title = "Roast"
            content.body = "\(notifications.count) PRs need your attention"
            post(id: "summary", content: content)
            return
        }

        for notification in notifications {
            Task {
                let content = UNMutableNotificationContent()
                content.title = notification.title
                content.subtitle = notification.subtitle
                content.body = notification.body
                content.threadIdentifier = notification.threadID
                content.userInfo = ["prID": notification.prID, "url": notification.url.absoluteString]
                if let avatar = await Self.avatarAttachment(for: notification.actor) {
                    content.attachments = [avatar]
                }
                post(id: notification.prID, content: content)
            }
        }
    }

    nonisolated static func notifications(for events: [PREvent]) -> [PRNotification] {
        var order: [PullRequest] = []
        var primary: [String: PREvent] = [:]
        var comments: [String: Int] = [:]
        var commenters: [String: String] = [:]

        for event in events {
            let id = event.pr.id
            if !order.contains(event.pr) { order.append(event.pr) }
            if case .newComments(_, let count, let commenter) = event {
                comments[id, default: 0] += count
                commenters[id] = commenters[id] ?? commenter
            } else if primary[id] == nil {
                primary[id] = event
            }
        }

        return order.map { pr in
            let commentCount = comments[pr.id] ?? 0
            if let event = primary[pr.id] {
                return notification(for: event, extraComments: commentCount)
            }
            return notification(for: .newComments(pr: pr, count: commentCount, by: commenters[pr.id] ?? pr.author))
        }
    }

    nonisolated static func notification(for event: PREvent, extraComments: Int = 0) -> PRNotification {
        let title: String
        let body: String
        let pr: PullRequest
        let actor: String

        switch event {
        case .reviewRequested(let requested, let reason):
            pr = requested
            actor = pr.author
            switch reason {
            case .requested:
                title = "Review requested"
                body = "\(pr.author) wants your review on \"\(pr.title)\""
            case .teamMemberPR:
                title = "New PR from \(pr.author)"
                body = "\"\(pr.title)\""
            case .staleReview:
                title = "New commits since your review"
                body = "\(pr.author) updated \"\(pr.title)\""
            }
        case .approved(let approved, let reviewer):
            pr = approved
            actor = reviewer
            title = "PR approved"
            body = "\(reviewer) approved \"\(pr.title)\""
        case .changesRequested(let changed, let reviewer):
            pr = changed
            actor = reviewer
            title = "Changes requested"
            body = "\(reviewer) requested changes on \"\(pr.title)\""
        case .newComments(let commented, let count, let commenter):
            pr = commented
            actor = commenter
            title = "New comments"
            body = "\(count) new comment\(count == 1 ? "" : "s") on \"\(pr.title)\""
        }

        let suffix = extraComments > 0 ? " (+\(extraComments) comment\(extraComments == 1 ? "" : "s"))" : ""
        return PRNotification(
            prID: pr.id, url: pr.url, title: title, subtitle: pr.repoName, body: body + suffix, threadID: pr.repoName,
            actor: actor
        )
    }

    nonisolated static func avatarURL(for login: String) -> URL {
        URL(string: "https://github.com/\(login).png?size=128")!
    }

    private static func avatarAttachment(for login: String) async -> UNNotificationAttachment? {
        var request = URLRequest(url: avatarURL(for: login))
        request.timeoutInterval = 5
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let ext = response.mimeType == "image/jpeg" ? "jpg" : "png"
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        guard (try? data.write(to: file)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "avatar", url: file)
    }

    private func post(id: String, content: UNMutableNotificationContent) {
        content.sound = .default
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
