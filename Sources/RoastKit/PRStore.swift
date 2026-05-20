import Foundation

public final class PRStore {
    private let preferences: PreferencesStore
    private let currentUser: String

    public private(set) var categorised: CategorisedPRs = .empty
    public private(set) var previousCategorised: CategorisedPRs = .empty

    // Track last-seen comment counts in memory so first-seen PRs get baseline seeded
    // without persisting until explicitly marked seen
    private var seenCommentCounts: [String: Int] = [:]

    public init(preferences: PreferencesStore, currentUser: String) {
        self.preferences = preferences
        self.currentUser = currentUser
    }

    @discardableResult
    public func categorise(_ prs: [PullRequest]) -> CategorisedPRs {
        previousCategorised = categorised

        var myPRs: [PullRequest] = []
        var needsMyReview: [PullRequest] = []
        var newActivity: [PullRequest] = []

        for pr in prs {
            // Rule 1: authored by current user - first match wins
            if pr.author == currentUser {
                myPRs.append(pr)
                seedBaselineIfNeeded(pr)
                continue
            }

            // Rule 2: review requested and not yet reviewed
            let isReviewRequested = isReviewRequestedForMe(pr)
            let hasReviewed = pr.latestVerdictByUser[currentUser] != nil

            if isReviewRequested && !hasReviewed {
                needsMyReview.append(pr)
                seedBaselineIfNeeded(pr)
                continue
            }

            // Rule 3: new activity (comment count increased since last seen)
            seedBaselineIfNeeded(pr)
            let lastSeen = seenCommentCounts[pr.id] ?? preferences.lastSeenCommentCount(forPR: pr.id)
            if let baseline = lastSeen, pr.commentCount > baseline {
                newActivity.append(pr)
            }
        }

        categorised = CategorisedPRs(
            needsMyReview: needsMyReview,
            myPRs: myPRs,
            newActivity: newActivity
        )
        return categorised
    }

    public func markSeen(_ pr: PullRequest) {
        preferences.setLastSeenCommentCount(pr.commentCount, forPR: pr.id)
        seenCommentCounts[pr.id] = pr.commentCount
        preferences.setLastSeenVerdict(pr.overallVerdict, forPR: pr.id)
    }

    public var badgeCount: Int {
        let changedVerdictCount = categorised.myPRs.filter { pr in
            let previous = preferences.lastSeenVerdict(forPR: pr.id)
            return previous != nil && previous != pr.overallVerdict
        }.count
        return categorised.needsMyReview.count + changedVerdictCount + categorised.newActivity.count
    }

    public var newCommentCounts: [String: Int] {
        var result: [String: Int] = [:]
        for pr in categorised.newActivity {
            let baseline = seenCommentCounts[pr.id] ?? preferences.lastSeenCommentCount(forPR: pr.id) ?? 0
            let delta = pr.commentCount - baseline
            if delta > 0 {
                result[pr.id] = delta
            }
        }
        return result
    }

    // MARK: - Private

    private func isReviewRequestedForMe(_ pr: PullRequest) -> Bool {
        if pr.reviewRequestedLogins.contains(currentUser) { return true }
        if pr.bodyMentionsTeam { return true }
        let team = preferences.teamName
        if !team.isEmpty && pr.reviewRequestedTeams.contains(team) { return true }
        return false
    }

    private func seedBaselineIfNeeded(_ pr: PullRequest) {
        guard seenCommentCounts[pr.id] == nil,
              preferences.lastSeenCommentCount(forPR: pr.id) == nil else { return }
        seenCommentCounts[pr.id] = pr.commentCount
    }
}
