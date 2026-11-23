import Foundation
@testable import RoastKit

enum GitHubClientTests {
    static func prNode(comments: [String], reviews: [(author: String, inlineComments: Int)], bots: Set<String> = []) -> [String: Any] {
        func author(_ login: String) -> [String: Any] {
            ["login": login, "__typename": bots.contains(login) ? "Bot" : "User"]
        }
        return [
            "id": "PR_1",
            "number": 1,
            "title": "Add widget",
            "url": "https://github.com/org/repo/pull/1",
            "createdAt": "2026-09-24T09:00:00Z",
            "author": ["login": "bob"],
            "repository": ["name": "repo", "isArchived": false],
            "comments": ["nodes": comments.map { ["author": author($0)] }],
            "reviews": ["nodes": reviews.map {
                ["author": author($0.author), "state": "COMMENTED", "comments": ["totalCount": $0.inlineComments]]
            }],
        ]
    }

    static func run() {
        suite("GitHubClient parsePRNode comment counts") {
            test("counts conversation and inline review comments per author") {
                let client = GitHubClient(token: "unused")
                let node = prNode(
                    comments: ["carol", "bob", "carol"],
                    reviews: [(author: "carol", inlineComments: 3), (author: "bob", inlineComments: 1)]
                )
                let pr = client.parsePRNode(node, bodyMentionsTeam: false)
                try expect(pr?.commentCountsByAuthor ?? [:], ["carol": 5, "bob": 2])
            }

            test("ignores comments from bots") {
                let client = GitHubClient(token: "unused")
                let node = prNode(
                    comments: ["carol", "codacy"],
                    reviews: [(author: "copilot-pull-request-reviewer", inlineComments: 4)],
                    bots: ["codacy", "copilot-pull-request-reviewer"]
                )
                let pr = client.parsePRNode(node, bodyMentionsTeam: false)
                try expect(pr?.commentCountsByAuthor ?? [:], ["carol": 1])
            }
        }

        suite("GitHubClient parsePRNode merge readiness") {
            test("reads GitHub's review decision") {
                var node = prNode(comments: [], reviews: [])
                node["reviewDecision"] = "REVIEW_REQUIRED"
                let pr = GitHubClient(token: "unused").parsePRNode(node, bodyMentionsTeam: false)
                try expect(pr?.reviewDecision, .reviewRequired)
            }

            test("no review decision when the repo requires no reviews") {
                var node = prNode(comments: [], reviews: [])
                node["reviewDecision"] = NSNull()
                let pr = GitHubClient(token: "unused").parsePRNode(node, bodyMentionsTeam: false)
                try expect(pr?.reviewDecision, nil)
            }

            for state in ["CLEAN", "HAS_HOOKS", "UNSTABLE"] {
                test("mergeable when merge state is \(state)") {
                    var node = prNode(comments: [], reviews: [])
                    node["mergeStateStatus"] = state
                    let pr = GitHubClient(token: "unused").parsePRNode(node, bodyMentionsTeam: false)
                    try expect(pr?.isMergeable, true)
                }
            }

            for state in ["BLOCKED", "BEHIND", "DIRTY", "DRAFT", "UNKNOWN"] {
                test("not mergeable when merge state is \(state)") {
                    var node = prNode(comments: [], reviews: [])
                    node["mergeStateStatus"] = state
                    let pr = GitHubClient(token: "unused").parsePRNode(node, bodyMentionsTeam: false)
                    try expect(pr?.isMergeable, false)
                }
            }
        }
    }
}
