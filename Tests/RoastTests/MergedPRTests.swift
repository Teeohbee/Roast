import Foundation
@testable import RoastKit

enum MergedPRTests {
    static func response(_ nodes: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: ["data": ["merged": ["nodes": nodes]]])
    }

    static func node(number: Int, mergedAt: String?) -> [String: Any] {
        [
            "number": number,
            "title": "PR \(number)",
            "url": "https://github.com/org/repo/pull/\(number)",
            "mergedAt": mergedAt ?? NSNull(),
            "repository": ["name": "repo"],
        ]
    }

    static func run() {
        suite("GitHubClient parseMergedPRs") {
            test("orders by merge time, newest first") {
                let client = GitHubClient(token: "unused")
                let prs = try client.parseMergedPRs(data: response([
                    node(number: 1, mergedAt: "2026-11-10T09:00:00Z"),
                    node(number: 2, mergedAt: "2026-11-17T09:00:00Z"),
                    node(number: 3, mergedAt: "2026-11-12T09:00:00Z"),
                ]), limit: 10)
                try expect(prs.map(\.number), [2, 3, 1])
            }

            test("keeps only the most recent up to the limit") {
                let client = GitHubClient(token: "unused")
                let prs = try client.parseMergedPRs(data: response([
                    node(number: 1, mergedAt: "2026-11-10T09:00:00Z"),
                    node(number: 2, mergedAt: "2026-11-17T09:00:00Z"),
                    node(number: 3, mergedAt: "2026-11-12T09:00:00Z"),
                ]), limit: 2)
                try expect(prs.map(\.number), [2, 3])
            }

            test("carries title, repo and link") {
                let client = GitHubClient(token: "unused")
                let pr = try client.parseMergedPRs(data: response([
                    node(number: 7, mergedAt: "2026-11-10T09:00:00Z"),
                ]), limit: 10).first
                try expect(pr?.title, "PR 7")
                try expect(pr?.repoName, "repo")
                try expect(pr?.url, URL(string: "https://github.com/org/repo/pull/7"))
            }

            test("skips PRs without a merge time") {
                let client = GitHubClient(token: "unused")
                let prs = try client.parseMergedPRs(data: response([
                    node(number: 1, mergedAt: nil),
                    node(number: 2, mergedAt: "2026-11-17T09:00:00Z"),
                ]), limit: 10)
                try expect(prs.map(\.number), [2])
            }
        }
    }
}
