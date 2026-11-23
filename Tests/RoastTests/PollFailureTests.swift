import Foundation
@testable import RoastKit

enum PollFailureTests {
    static func run() {
        suite("PollFailure") {
            test("401 asks you to check the token") {
                let failure = PollFailure(GitHubError.httpError(401, "Bad credentials"))
                try expect(failure.menuMessage, "Authentication failed - check token")
            }

            test("other HTTP errors show the status code") {
                let failure = PollFailure(GitHubError.httpError(502, "<html>Bad gateway</html>"))
                try expect(failure.menuMessage, "GitHub API error (502)")
            }

            test("GraphQL errors show the first message") {
                let failure = PollFailure(GitHubError.graphQLErrors(["Something went wrong while executing your query", "other"]))
                try expect(failure.menuMessage, "Something went wrong while executing your query")
            }

            test("other GitHub errors show a generic message") {
                try expect(PollFailure(GitHubError.invalidResponse).menuMessage, "Failed to fetch PRs")
            }

            test("non-GitHub errors show a network error") {
                try expect(PollFailure(URLError(.notConnectedToInternet)).menuMessage, "Network error")
            }

            test("HTTP log detail has the status code and response body") {
                let failure = PollFailure(GitHubError.httpError(502, "Bad gateway"))
                try expect(failure.logDetail, "HTTP 502: Bad gateway")
            }

            test("HTTP log detail truncates a long response body") {
                let failure = PollFailure(GitHubError.httpError(500, String(repeating: "x", count: 5000)))
                try expect(failure.logDetail, "HTTP 500: " + String(repeating: "x", count: 1000) + "…")
            }

            test("GraphQL log detail has every message") {
                let failure = PollFailure(GitHubError.graphQLErrors(["first", "second"]))
                try expect(failure.logDetail, "GraphQL errors: first; second")
            }

            test("log detail for other errors describes the underlying error") {
                let failure = PollFailure(URLError(.notConnectedToInternet))
                try expect(failure.logDetail.contains("NSURLErrorDomain"), "got \(failure.logDetail)")
                try expect(failure.logDetail.contains("-1009"), "got \(failure.logDetail)")
            }

            test("an auth failure isn't retried") {
                try expect(!PollFailure(GitHubError.httpError(401, "Bad credentials")).isRetryable)
            }

            test("a server error is retried") {
                try expect(PollFailure(GitHubError.httpError(502, "")).isRetryable)
            }

            test("a GraphQL search timeout is retried") {
                try expect(PollFailure(GitHubError.graphQLErrors(["Something went wrong while executing your query"])).isRetryable)
            }

            test("a network error is retried") {
                try expect(PollFailure(URLError(.notConnectedToInternet)).isRetryable)
            }
        }
    }
}
