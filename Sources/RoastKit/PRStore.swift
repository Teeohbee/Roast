import Foundation

public final class PRStore {
    private let preferences: PreferencesStore
    private let currentUser: String

    public private(set) var categorised: CategorisedPRs = .empty
    public private(set) var previousCategorised: CategorisedPRs = .empty

    private var seenCommentCounts: [String: Int] = [:]
    private var pollCount = 0
    private var reviewReasons: [String: ReviewReason] = [:]

    public init(preferences: PreferencesStore, currentUser: String) {
        self.preferences = preferences
        self.currentUser = currentUser
    }

    @discardableResult
    public func categorise(_ prs: [PullRequest], teamMembers: [String] = []) -> CategorisedPRs {
        previousCategorised = categorised
        pollCount += 1
        let teamMemberSet = Set(teamMembers)

        var myPRs: [PullRequest] = []
        var needsMyReview: [PullRequest] = []
        reviewReasons = [:]

        for pr in prs {
            seedBaselineIfNeeded(pr)

            if pr.author == currentUser {
                myPRs.append(pr)
                continue
            }

            if pr.isDraft { continue }

            let verdict = pr.latestVerdictByUser[currentUser]
            let hasReviewed = verdict == .approved || verdict == .changesRequested
            let isRequested = isReviewRequestedForMe(pr)
            let needsReview = isRequested || teamMemberSet.contains(pr.author)
            let isStale = pr.isReviewStale(for: currentUser)

            if needsReview && (!hasReviewed || isStale) {
                needsMyReview.append(pr)
                reviewReasons[pr.id] = hasReviewed ? .staleReview : isRequested ? .requested : .teamMemberPR
            }
        }

        categorised = CategorisedPRs(
            needsMyReview: needsMyReview,
            myPRs: myPRs
        )
        return categorised
    }

    public func markSeen(_ pr: PullRequest) {
        let count = pr.commentCount(excluding: currentUser)
        preferences.setLastSeenCommentCount(count, forPR: pr.id)
        seenCommentCounts[pr.id] = count
        preferences.setLastSeenVerdict(pr.overallVerdict, forPR: pr.id)
    }

    public var badgeCount: Int {
        let myPRsWithNewComments = categorised.myPRs.filter { newCommentCount(for: $0) > 0 }.count
        return categorised.needsMyReview.count + myPRsWithNewComments
    }

    public func newCommentCount(for pr: PullRequest) -> Int {
        let count = pr.commentCount(excluding: currentUser)
        let baseline = seenCommentCounts[pr.id] ?? preferences.lastSeenCommentCount(forPR: pr.id) ?? count
        return max(count - baseline, 0)
    }

    public func isStaleReview(_ pr: PullRequest) -> Bool {
        pr.isReviewStale(for: currentUser)
    }

    public func detectChanges() -> [PREvent] {
        guard pollCount > 1 else { return [] }
        var events: [PREvent] = []

        let previousReviewIDs = Set(previousCategorised.needsMyReview.map(\.id))
        for pr in categorised.needsMyReview where !previousReviewIDs.contains(pr.id) {
            events.append(.reviewRequested(pr: pr, reason: reviewReasons[pr.id] ?? .requested))
        }

        let previousMyPRsByID = Dictionary(uniqueKeysWithValues: previousCategorised.myPRs.map { ($0.id, $0) })
        for pr in categorised.myPRs {
            if let previous = previousMyPRsByID[pr.id] {
                let added = pr.commentCount(excluding: currentUser) - previous.commentCount(excluding: currentUser)
                if added > 0 {
                    events.append(.newComments(pr: pr, count: added))
                }
            }

            let previousVerdict = previousMyPRsByID[pr.id]?.overallVerdict ?? .pending
            let currentVerdict = pr.overallVerdict
            guard currentVerdict != previousVerdict else { continue }

            switch currentVerdict {
            case .approved:
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

        return events
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
        seenCommentCounts[pr.id] = pr.commentCount(excluding: currentUser)
    }
}
