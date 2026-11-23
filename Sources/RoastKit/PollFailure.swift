import Foundation
import os

extension Logger {
    static let poller = Logger(subsystem: "com.toby.roast", category: "poller")
}

struct PollFailure {
    static let maxBodyLength = 1000

    let menuMessage: String
    let logDetail: String
    let isRetryable: Bool

    init(_ error: Error) {
        switch error {
        case GitHubError.httpError(let code, let body):
            menuMessage = code == 401 ? "Authentication failed - check token" : "GitHub API error (\(code))"
            logDetail = "HTTP \(code): \(Self.truncated(body))"
            isRetryable = code != 401
        case GitHubError.graphQLErrors(let messages):
            menuMessage = messages.first ?? "GraphQL error"
            logDetail = "GraphQL errors: \(messages.joined(separator: "; "))"
            isRetryable = true
        case is GitHubError:
            menuMessage = "Failed to fetch PRs"
            logDetail = String(describing: error)
            isRetryable = true
        default:
            menuMessage = "Network error"
            logDetail = String(describing: error)
            isRetryable = true
        }
    }

    private static func truncated(_ body: String) -> String {
        body.count > maxBodyLength ? body.prefix(maxBodyLength) + "…" : body
    }
}
