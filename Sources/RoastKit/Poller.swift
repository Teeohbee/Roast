// ~/Projects/Roast/Sources/RoastKit/Poller.swift
import Foundation

@MainActor
public final class Poller {
    private let preferences: PreferencesStore
    private let statusBar: StatusBarController
    private let notifications: NotificationManager
    private var prStore: PRStore?
    private var gitHubClient: GitHubClient?
    private var cachedMembers: [String] = []
    private var lastMemberFetch: Date = .distantPast
    private var timer: Timer?

    public init(
        preferences: PreferencesStore,
        statusBar: StatusBarController,
        notifications: NotificationManager
    ) {
        self.preferences = preferences
        self.statusBar = statusBar
        self.notifications = notifications
    }

    public func start() {
        scheduleTimer()
        poll()
    }

    public func poll() {
        guard let token = KeychainStore.loadToken(), !token.isEmpty else {
            statusBar.showError("No GitHub token - open Settings")
            return
        }

        let org = preferences.org
        let teamName = preferences.teamName
        guard !org.isEmpty, !teamName.isEmpty else {
            statusBar.showError("No team configured - open Settings")
            return
        }

        if gitHubClient == nil {
            gitHubClient = GitHubClient(token: token)
        }

        Task {
            do {
                let client = gitHubClient!

                if prStore == nil {
                    let viewer = try await client.fetchViewer()
                    prStore = PRStore(preferences: preferences, currentUser: viewer)
                }

                if Date().timeIntervalSince(lastMemberFetch) > 3600 {
                    cachedMembers = try await client.fetchTeamMembers(org: org, team: teamName)
                    lastMemberFetch = Date()
                }

                let prs = try await client.fetchPRs(org: org, team: teamName, members: cachedMembers)
                let store = prStore!
                let categorised = store.categorise(prs, teamMembers: cachedMembers)
                let events = store.detectChanges()

                statusBar.update(categorised: categorised, badgeCount: store.badgeCount, newCommentCounts: store.newCommentCounts)
                notifications.deliver(events)
            } catch let error as GitHubError {
                switch error {
                case .httpError(401, _):
                    statusBar.showError("Authentication failed - check token")
                case .httpError(let code, _):
                    statusBar.showError("GitHub API error (\(code))")
                case .graphQLErrors(let messages):
                    statusBar.showError(messages.first ?? "GraphQL error")
                default:
                    statusBar.showError("Failed to fetch PRs")
                }
            } catch {
                statusBar.showError("Network error")
            }
        }
    }

    public func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(preferences.pollIntervalMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
    }

    public func resetClient() {
        gitHubClient = nil
        prStore = nil
        cachedMembers = []
        lastMemberFetch = .distantPast
    }

    public func markSeen(_ pr: PullRequest) {
        prStore?.markSeen(pr)
    }
}
