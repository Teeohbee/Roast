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
    public func categorise(_ prs: [PullRequest], teamMembers: [String] = []) -> CategorisedPRs {
        previousCategorised = categorised
        let teamMemberSet = Set(teamMembers)

        var myPRs: [PullRequest] = []
        var needsMyReview: [PullRequest] = []
        var newActivity: [PullRequest] = []
        var drafts: [PullRequest] = []

        for pr in prs {
            if pr.author == currentUser {
                myPRs.append(pr)
                seedBaselineIfNeeded(pr)
                continue
            }

            let hasReviewed = pr.latestVerdictByUser[currentUser] != nil
            let needsReview = isReviewRequestedForMe(pr) || teamMemberSet.contains(pr.author)

            if needsReview && !hasReviewed {
                if pr.isDraft {
                    drafts.append(pr)
                } else {
                    needsMyReview.append(pr)
                }
                seedBaselineIfNeeded(pr)
                continue
            }

            seedBaselineIfNeeded(pr)
            let lastSeen = seenCommentCounts[pr.id] ?? preferences.lastSeenCommentCount(forPR: pr.id)
            if let baseline = lastSeen, pr.commentCount > baseline {
                newActivity.append(pr)
            }
        }

        categorised = CategorisedPRs(
            needsMyReview: needsMyReview,
            myPRs: myPRs,
            newActivity: newActivity,
            drafts: drafts
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

    public func detectChanges() -> [PREvent] {
        var events: [PREvent] = []

        // 1. New review requests: PRs in current needsMyReview that weren't in previous
        let previousReviewIDs = Set(previousCategorised.needsMyReview.map(\.id))
        for pr in categorised.needsMyReview where !previousReviewIDs.contains(pr.id) {
            events.append(.reviewRequested(pr: pr))
        }

        // 2. New verdicts on my PRs: compare overallVerdict between previous and current
        let previousMyPRsByID = Dictionary(uniqueKeysWithValues: previousCategorised.myPRs.map { ($0.id, $0) })
        for pr in categorised.myPRs {
            let previousVerdict = previousMyPRsByID[pr.id]?.overallVerdict ?? .pending
            let currentVerdict = pr.overallVerdict
            guard currentVerdict != previousVerdict else { continue }

            switch currentVerdict {
            case .approved:
                // Find the reviewer who is newly approving
                let previousVerdicts = previousMyPRsByID[pr.id]?.latestVerdictByUser ?? [:]
                if let reviewer = pr.latestVerdictByUser.first(where: { user, verdict in
                    verdict == .approved && previousVerdicts[user] != .approved
                })?.key {
                    events.append(.approved(pr: pr, reviewer: reviewer))
                }
            case .changesRequested:
                let previousVerdicts = previousMyPRsByID[pr.id]?.latestVerdictByUser ?? [:]
                if let reviewer = pr.latestVerdictByUser.first(where: { user, verdict in
                    verdict == .changesRequested && previousVerdicts[user] != .changesRequested
                })?.key {
                    events.append(.changesRequested(pr: pr, reviewer: reviewer))
                }
            default:
                break
            }
        }

        // 3. New comments: PRs in current newActivity that weren't in previous newActivity
        let previousActivityByID = Dictionary(uniqueKeysWithValues: previousCategorised.newActivity.map { ($0.id, $0) })
        for pr in categorised.newActivity {
            let previousCount = previousActivityByID[pr.id]?.commentCount ?? (seenCommentCounts[pr.id] ?? 0)
            let delta = pr.commentCount - previousCount
            if delta > 0 {
                events.append(.newComments(pr: pr, count: delta))
            }
        }

        return events
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
