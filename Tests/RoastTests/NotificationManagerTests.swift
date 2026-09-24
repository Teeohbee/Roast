import Foundation
@testable import RoastKit

enum NotificationManagerTests {
    static func run() {
        suite("NotificationManager text") {
            test("stale review says new commits") {
                let pr = ModelsTests.makePR(title: "Add widget", author: "alice", repoName: "chopin")
                let n = NotificationManager.notification(for: .reviewRequested(pr: pr, reason: .staleReview))
                try expect(n.title, "New commits since your review")
                try expect(n.subtitle, "chopin")
                try expect(n.body, "alice updated \"Add widget\"")
            }

            test("notifications are grouped by repo") {
                let pr = ModelsTests.makePR(repoName: "chopin")
                try expect(NotificationManager.notification(for: .approved(pr: pr, reviewer: "carol")).threadID, "chopin")
            }

            test("team member PR names the author") {
                let pr = ModelsTests.makePR(author: "alice")
                try expect(NotificationManager.notification(for: .reviewRequested(pr: pr, reason: .teamMemberPR)).title, "New PR from alice")
            }

            test("extra comments are appended") {
                let pr = ModelsTests.makePR(title: "Add widget", repoName: "chopin")
                let n = NotificationManager.notification(for: .changesRequested(pr: pr, reviewer: "carol"), extraComments: 4)
                try expect(n.body, "carol requested changes on \"Add widget\" (+4 comments)")
            }
        }

        suite("NotificationManager grouping") {
            test("verdict and comments on one PR become one notification") {
                let pr = ModelsTests.makePR(id: "PR_1", title: "Add widget", repoName: "chopin")
                let result = NotificationManager.notifications(for: [
                    .newComments(pr: pr, count: 4),
                    .changesRequested(pr: pr, reviewer: "carol"),
                ])
                try expect(result, [NotificationManager.notification(for: .changesRequested(pr: pr, reviewer: "carol"), extraComments: 4)])
            }

            test("comments alone stay a comments notification") {
                let pr = ModelsTests.makePR(id: "PR_1")
                let result = NotificationManager.notifications(for: [.newComments(pr: pr, count: 2)])
                try expect(result, [NotificationManager.notification(for: .newComments(pr: pr, count: 2))])
            }

            test("different PRs stay separate, in event order") {
                let first = ModelsTests.makePR(id: "PR_1")
                let second = ModelsTests.makePR(id: "PR_2")
                let result = NotificationManager.notifications(for: [
                    .reviewRequested(pr: second, reason: .requested),
                    .approved(pr: first, reviewer: "carol"),
                ])
                try expect(result.map(\.prID), ["PR_2", "PR_1"])
            }
        }
    }
}
