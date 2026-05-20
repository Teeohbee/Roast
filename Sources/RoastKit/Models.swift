import Foundation

public enum ReviewVerdict: String, Equatable, Sendable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case commented = "COMMENTED"
    case pending = "PENDING"
}

public struct Review: Equatable, Sendable {
    public let author: String
    public let verdict: ReviewVerdict

    public init(author: String, verdict: ReviewVerdict) {
        self.author = author
        self.verdict = verdict
    }
}

public struct PullRequest: Sendable {
    public let id: String
    public let number: Int
    public let title: String
    public let author: String
    public let repoName: String
    public let url: URL
    public let createdAt: Date
    public let reviewRequestedLogins: [String]
    public let reviewRequestedTeams: [String]
    public let bodyMentionsTeam: Bool
    public let latestReviews: [Review]
    public let commentCount: Int

    public init(
        id: String,
        number: Int,
        title: String,
        author: String,
        repoName: String,
        url: URL,
        createdAt: Date,
        reviewRequestedLogins: [String],
        reviewRequestedTeams: [String],
        bodyMentionsTeam: Bool,
        latestReviews: [Review],
        commentCount: Int
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.author = author
        self.repoName = repoName
        self.url = url
        self.createdAt = createdAt
        self.reviewRequestedLogins = reviewRequestedLogins
        self.reviewRequestedTeams = reviewRequestedTeams
        self.bodyMentionsTeam = bodyMentionsTeam
        self.latestReviews = latestReviews
        self.commentCount = commentCount
    }

    public var relativeAge: String {
        let seconds = Int(Date().timeIntervalSince(createdAt))
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        if days >= 1 {
            return "\(days)d"
        } else if hours >= 1 {
            return "\(hours)h"
        } else {
            return "\(max(minutes, 0))m"
        }
    }

    /// Last review verdict per reviewer (final entry in latestReviews wins).
    public var latestVerdictByUser: [String: ReviewVerdict] {
        latestReviews.reduce(into: [:]) { result, review in
            result[review.author] = review.verdict
        }
    }

    /// changesRequested > approved > pending
    public var overallVerdict: ReviewVerdict {
        let verdicts = Set(latestVerdictByUser.values)
        if verdicts.contains(.changesRequested) { return .changesRequested }
        if verdicts.contains(.approved) { return .approved }
        return .pending
    }
}

extension PullRequest: Equatable {
    public static func == (lhs: PullRequest, rhs: PullRequest) -> Bool {
        lhs.id == rhs.id
    }
}

extension PullRequest: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct CategorisedPRs: Equatable, Sendable {
    public let needsMyReview: [PullRequest]
    public let myPRs: [PullRequest]
    public let newActivity: [PullRequest]

    public init(needsMyReview: [PullRequest], myPRs: [PullRequest], newActivity: [PullRequest]) {
        self.needsMyReview = needsMyReview
        self.myPRs = myPRs
        self.newActivity = newActivity
    }

    public static let empty = CategorisedPRs(needsMyReview: [], myPRs: [], newActivity: [])
}

public enum PREvent: Equatable, Sendable {
    case reviewRequested(pr: PullRequest)
    case approved(pr: PullRequest, reviewer: String)
    case changesRequested(pr: PullRequest, reviewer: String)
    case newComments(pr: PullRequest, count: Int)
}
