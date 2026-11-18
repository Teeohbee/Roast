import Foundation

public enum ReviewVerdict: String, Equatable, Sendable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case commented = "COMMENTED"
    case pending = "PENDING"
}

public enum CIStatus: String, Equatable, Sendable {
    case success = "SUCCESS"
    case failure = "FAILURE"
    case pending = "PENDING"
    case error = "ERROR"
    case expected = "EXPECTED"
    case unknown
}

public struct Review: Equatable, Sendable {
    public let author: String
    public let verdict: ReviewVerdict
    public let submittedAt: Date?

    public init(author: String, verdict: ReviewVerdict, submittedAt: Date? = nil) {
        self.author = author
        self.verdict = verdict
        self.submittedAt = submittedAt
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
    public let commentCountsByAuthor: [String: Int]
    public let isDraft: Bool
    public let ciStatus: CIStatus
    public let lastCommitDate: Date?

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
        commentCountsByAuthor: [String: Int],
        isDraft: Bool = false,
        ciStatus: CIStatus = .unknown,
        lastCommitDate: Date? = nil
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
        self.commentCountsByAuthor = commentCountsByAuthor
        self.isDraft = isDraft
        self.ciStatus = ciStatus
        self.lastCommitDate = lastCommitDate
    }

    public func commentCount(excluding user: String) -> Int {
        commentCountsByAuthor.filter { $0.key != user }.values.reduce(0, +)
    }

    public func isReviewStale(for user: String) -> Bool {
        guard let commitDate = lastCommitDate else { return false }
        let myReviews = verdictReviews.filter { $0.author == user }
        guard let latestReview = myReviews.last, let reviewDate = latestReview.submittedAt else { return false }
        return commitDate > reviewDate
    }

    public var jiraTicket: String? {
        RoastKit.jiraTicket(in: title)
    }

    public var jiraURL: URL? {
        RoastKit.jiraURL(in: title)
    }

    public var relativeAge: String {
        RoastKit.relativeAge(since: createdAt)
    }

    private var verdictReviews: [Review] {
        latestReviews.filter { $0.verdict == .approved || $0.verdict == .changesRequested }
    }

    public var latestVerdictByUser: [String: ReviewVerdict] {
        verdictReviews.reduce(into: [:]) { result, review in
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

public struct MergedPullRequest: Equatable, Sendable {
    public let number: Int
    public let title: String
    public let repoName: String
    public let url: URL
    public let mergedAt: Date

    public var jiraURL: URL? {
        RoastKit.jiraURL(in: title)
    }

    public var relativeAge: String {
        RoastKit.relativeAge(since: mergedAt)
    }
}

func jiraTicket(in title: String) -> String? {
    let pattern = /[A-Z]+-\d+/
    return title.firstMatch(of: pattern).map { String($0.output) }
}

func jiraURL(in title: String) -> URL? {
    guard let ticket = jiraTicket(in: title) else { return nil }
    return URL(string: "https://simplybusiness.atlassian.net/browse/\(ticket)")
}

func relativeAge(since date: Date) -> String {
    let seconds = Int(Date().timeIntervalSince(date))
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

public struct CategorisedPRs: Equatable, Sendable {
    public let needsMyReview: [PullRequest]
    public let myPRs: [PullRequest]

    public init(needsMyReview: [PullRequest], myPRs: [PullRequest]) {
        self.needsMyReview = needsMyReview
        self.myPRs = myPRs
    }

    public static let empty = CategorisedPRs(needsMyReview: [], myPRs: [])
}

public enum ReviewReason: Equatable, Sendable {
    case requested
    case teamMemberPR
    case staleReview
}

public enum PREvent: Equatable, Sendable {
    case reviewRequested(pr: PullRequest, reason: ReviewReason)
    case approved(pr: PullRequest, reviewer: String)
    case changesRequested(pr: PullRequest, reviewer: String)
    case newComments(pr: PullRequest, count: Int, by: String)

    public var pr: PullRequest {
        switch self {
        case .reviewRequested(let pr, _), .approved(let pr, _), .changesRequested(let pr, _), .newComments(let pr, _, _):
            return pr
        }
    }
}
