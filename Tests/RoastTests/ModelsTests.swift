import Foundation
@testable import RoastKit

enum ModelsTests {
    static func makePR(
        id: String = "PR_1",
        number: Int = 42,
        title: String = "Add feature",
        author: String = "alice",
        repoName: String = "org/repo",
        url: URL = URL(string: "https://github.com/org/repo/pull/42")!,
        createdAt: Date = Date(),
        reviewRequestedLogins: [String] = [],
        reviewRequestedTeams: [String] = [],
        bodyMentionsTeam: Bool = false,
        latestReviews: [Review] = [],
        commentCount: Int = 0,
        commentCountsByAuthor: [String: Int]? = nil,
        isDraft: Bool = false,
        lastCommitDate: Date? = nil,
        reviewDecision: ReviewDecision? = nil,
        isMergeable: Bool = false
    ) -> PullRequest {
        PullRequest(
            id: id,
            number: number,
            title: title,
            author: author,
            repoName: repoName,
            url: url,
            createdAt: createdAt,
            reviewRequestedLogins: reviewRequestedLogins,
            reviewRequestedTeams: reviewRequestedTeams,
            bodyMentionsTeam: bodyMentionsTeam,
            latestReviews: latestReviews,
            commentCountsByAuthor: commentCountsByAuthor ?? (commentCount > 0 ? ["carol": commentCount] : [:]),
            isDraft: isDraft,
            lastCommitDate: lastCommitDate,
            reviewDecision: reviewDecision,
            isMergeable: isMergeable
        )
    }

    static func run() {
        suite("PullRequest equality") {
            test("equal when same id, different title") {
                let pr1 = makePR(id: "PR_1", title: "Original title")
                let pr2 = makePR(id: "PR_1", title: "Changed title")
                try expect(pr1 == pr2, "PRs with same id should be equal")
            }

            test("not equal when different id") {
                let pr1 = makePR(id: "PR_1")
                let pr2 = makePR(id: "PR_2")
                try expect(pr1 != pr2, "PRs with different ids should not be equal")
            }
        }

        suite("ReviewVerdict raw values") {
            test("approved matches GitHub API string") {
                try expect(ReviewVerdict.approved.rawValue, "APPROVED")
            }

            test("changesRequested matches GitHub API string") {
                try expect(ReviewVerdict.changesRequested.rawValue, "CHANGES_REQUESTED")
            }

            test("commented matches GitHub API string") {
                try expect(ReviewVerdict.commented.rawValue, "COMMENTED")
            }

            test("pending matches GitHub API string") {
                try expect(ReviewVerdict.pending.rawValue, "PENDING")
            }
        }

        suite("relativeAge") {
            test("shows minutes when less than an hour ago") {
                let tenMinutesAgo = Date(timeIntervalSinceNow: -10 * 60)
                let pr = makePR(createdAt: tenMinutesAgo)
                try expect(pr.relativeAge, "10m")
            }

            test("shows hours when less than a day ago") {
                let twoHoursAgo = Date(timeIntervalSinceNow: -2 * 60 * 60)
                let pr = makePR(createdAt: twoHoursAgo)
                try expect(pr.relativeAge, "2h")
            }

            test("shows days when more than a day ago") {
                let twoDaysAgo = Date(timeIntervalSinceNow: -2 * 24 * 60 * 60)
                let pr = makePR(createdAt: twoDaysAgo)
                try expect(pr.relativeAge, "2d")
            }
        }

        suite("latestVerdictByUser") {
            test("returns last review verdict per reviewer when multiple reviews exist") {
                let reviews = [
                    Review(author: "bob", verdict: .approved),
                    Review(author: "bob", verdict: .changesRequested),
                ]
                let pr = makePR(latestReviews: reviews)
                try expect(pr.latestVerdictByUser["bob"], .changesRequested)
            }

            test("returns correct verdict for each distinct reviewer") {
                let reviews = [
                    Review(author: "bob", verdict: .approved),
                    Review(author: "carol", verdict: .changesRequested),
                ]
                let pr = makePR(latestReviews: reviews)
                try expect(pr.latestVerdictByUser["bob"], .approved)
                try expect(pr.latestVerdictByUser["carol"], .changesRequested)
            }

            test("a later comment-only review keeps the reviewer's Verdict") {
                let reviews = [
                    Review(author: "carol", verdict: .approved),
                    Review(author: "carol", verdict: .commented),
                ]
                let pr = makePR(latestReviews: reviews)
                try expect(pr.latestVerdictByUser["carol"], .approved)
                try expect(pr.overallVerdict, .approved)
            }

            test("a reviewer who only commented has no Verdict") {
                let pr = makePR(latestReviews: [Review(author: "carol", verdict: .commented)])
                try expect(pr.latestVerdictByUser["carol"], nil)
                try expect(pr.overallVerdict, .pending)
            }
        }

        suite("overallVerdict") {
            test("approved when all reviews approve") {
                let reviews = [
                    Review(author: "bob", verdict: .approved),
                    Review(author: "carol", verdict: .approved),
                ]
                let pr = makePR(latestReviews: reviews)
                try expect(pr.overallVerdict, .approved)
            }

            test("changesRequested wins over approved") {
                let reviews = [
                    Review(author: "bob", verdict: .approved),
                    Review(author: "carol", verdict: .changesRequested),
                ]
                let pr = makePR(latestReviews: reviews)
                try expect(pr.overallVerdict, .changesRequested)
            }

            test("pending when no reviews") {
                let pr = makePR(latestReviews: [])
                try expect(pr.overallVerdict, .pending)
            }
        }

        suite("mergeReadiness") {
            let approval = [Review(author: "bob", verdict: .approved)]

            test("Ready to Merge when GitHub approves and the PR can merge") {
                let pr = makePR(latestReviews: approval, reviewDecision: .approved, isMergeable: true)
                try expect(pr.mergeReadiness, .readyToMerge)
            }

            test("approved but blocked, e.g. by required checks") {
                let pr = makePR(latestReviews: approval, reviewDecision: .approved, isMergeable: false)
                try expect(pr.mergeReadiness, .approved)
            }

            test("approved but a required review is still missing, e.g. a code owner") {
                let pr = makePR(latestReviews: approval, reviewDecision: .reviewRequired, isMergeable: false)
                try expect(pr.mergeReadiness, .reviewRequired)
            }

            test("Pending when a review is required and nobody has approved") {
                let pr = makePR(reviewDecision: .reviewRequired)
                try expect(pr.mergeReadiness, .pending)
            }

            test("Ready to Merge on an approved PR in a repo that requires no reviews") {
                let pr = makePR(latestReviews: approval, reviewDecision: nil, isMergeable: true)
                try expect(pr.mergeReadiness, .readyToMerge)
            }

            test("Pending without approval even when the repo would let it merge") {
                let pr = makePR(reviewDecision: nil, isMergeable: true)
                try expect(pr.mergeReadiness, .pending)
            }

            test("Changes Requested wins") {
                let reviews = approval + [Review(author: "carol", verdict: .changesRequested)]
                let pr = makePR(latestReviews: reviews, reviewDecision: .changesRequested)
                try expect(pr.mergeReadiness, .changesRequested)
            }
        }
    }
}
