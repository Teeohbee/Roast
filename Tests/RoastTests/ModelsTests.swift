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
        isDraft: Bool = false,
        lastCommitDate: Date? = nil
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
            commentCount: commentCount,
            isDraft: isDraft,
            lastCommitDate: lastCommitDate
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
    }
}
