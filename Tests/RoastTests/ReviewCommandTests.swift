import Foundation
@testable import RoastKit

enum ReviewCommandTests {
    static func run() {
        suite("ReviewCommand expansion") {
            test("fills url, repo and number") {
                let command = ReviewCommand.expand(
                    "claude -n 'review {repo}#{number}' '/hunk-pr-review {url}'",
                    url: "https://github.com/org/chopin/pull/42", repo: "chopin", number: 42
                )
                try expect(command, "claude -n 'review chopin#42' '/hunk-pr-review https://github.com/org/chopin/pull/42'")
            }

            test("fills a placeholder used more than once") {
                try expect(ReviewCommand.expand("{repo} {repo}", url: "", repo: "chopin", number: 1), "chopin chopin")
            }

            test("leaves unknown placeholders alone") {
                try expect(ReviewCommand.expand("echo {title}", url: "", repo: "chopin", number: 1), "echo {title}")
            }
        }
    }
}
