// ~/Projects/Roast/Sources/RoastKit/GitHubClient.swift
import Foundation

public enum GitHubError: Error {
    case noToken
    case invalidResponse
    case httpError(Int, String)
    case graphQLErrors([String])
}

public final class GitHubClient: @unchecked Sendable {
    private let token: String
    private let session: URLSession

    public init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    // MARK: - Viewer

    public func fetchViewer() async throws -> String {
        let query = #"{ "query": "{ viewer { login } }" }"#
        let data = try await graphQL(body: query)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let viewer = dataDict["viewer"] as? [String: Any],
              let login = viewer["login"] as? String else {
            throw GitHubError.invalidResponse
        }
        return login
    }

    // MARK: - Team Members

    public func fetchTeamMembers(org: String, team: String) async throws -> [String] {
        let query = """
        {
          "query": "{ organization(login: \\"\(org)\\") { team(slug: \\"\(team)\\") { members(first: 100) { nodes { login } } } } }"
        }
        """
        let data = try await graphQL(body: query)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let orgDict = dataDict["organization"] as? [String: Any],
              let teamDict = orgDict["team"] as? [String: Any],
              let members = teamDict["members"] as? [String: Any],
              let nodes = members["nodes"] as? [[String: Any]] else {
            throw GitHubError.invalidResponse
        }
        return nodes.compactMap { $0["login"] as? String }
    }

    // MARK: - PR Search

    public func fetchPRs(org: String, team: String, members: [String]) async throws -> [PullRequest] {
        let fragment = """
        ... on PullRequest {
          id
          number
          title
          url
          createdAt
          author { login }
          repository { name }
          reviewRequests(first: 20) {
            nodes {
              requestedReviewer {
                ... on User { login }
                ... on Team { slug }
              }
            }
          }
          reviews(last: 20) {
            nodes {
              author { login }
              state
            }
          }
          comments { totalCount }
        }
        """

        var aliases: [(name: String, searchQuery: String, isBodyMention: Bool)] = []

        for (i, member) in members.enumerated() {
            aliases.append((
                name: "author\(i)",
                searchQuery: "type:pr state:open author:\(member) org:\(org)",
                isBodyMention: false
            ))
        }

        aliases.append((
            name: "teamReview",
            searchQuery: "type:pr state:open review-requested:\(org)/\(team)",
            isBodyMention: false
        ))

        aliases.append((
            name: "bodyMention",
            searchQuery: "type:pr state:open \\\"@\(org)/\(team)\\\" in:body org:\(org)",
            isBodyMention: true
        ))

        let aliasQueries = aliases.map { alias in
            "\(alias.name): search(query: \"\(alias.searchQuery)\", type: ISSUE, first: 50) { nodes { \(fragment) } }"
        }.joined(separator: "\n")

        let fullQuery = "{ \(aliasQueries) }"
        let body = try JSONSerialization.data(
            withJSONObject: ["query": fullQuery],
            options: []
        )

        let data = try await graphQL(bodyData: body)
        return try parsePRResponse(data: data, aliases: aliases)
    }

    // MARK: - Response Parsing

    private func parsePRResponse(data: Data, aliases: [(name: String, searchQuery: String, isBodyMention: Bool)]) throws -> [PullRequest] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GitHubError.invalidResponse
        }

        if let errors = json["errors"] as? [[String: Any]] {
            let messages = errors.compactMap { $0["message"] as? String }
            throw GitHubError.graphQLErrors(messages)
        }

        guard let dataDict = json["data"] as? [String: Any] else {
            throw GitHubError.invalidResponse
        }

        let bodyMentionAliases = Set(aliases.filter(\.isBodyMention).map(\.name))
        var prsById: [String: PullRequest] = [:]

        for alias in aliases {
            guard let searchResult = dataDict[alias.name] as? [String: Any],
                  let nodes = searchResult["nodes"] as? [[String: Any]] else { continue }

            let isBodyMention = bodyMentionAliases.contains(alias.name)

            for node in nodes {
                guard let pr = parsePRNode(node, bodyMentionsTeam: isBodyMention) else { continue }
                if let existing = prsById[pr.id] {
                    if isBodyMention && !existing.bodyMentionsTeam {
                        prsById[pr.id] = PullRequest(
                            id: existing.id,
                            number: existing.number,
                            title: existing.title,
                            author: existing.author,
                            repoName: existing.repoName,
                            url: existing.url,
                            createdAt: existing.createdAt,
                            reviewRequestedLogins: existing.reviewRequestedLogins,
                            reviewRequestedTeams: existing.reviewRequestedTeams,
                            bodyMentionsTeam: true,
                            latestReviews: existing.latestReviews,
                            commentCount: existing.commentCount
                        )
                    }
                } else {
                    prsById[pr.id] = pr
                }
            }
        }

        return Array(prsById.values)
    }

    private func parsePRNode(_ node: [String: Any], bodyMentionsTeam: Bool) -> PullRequest? {
        guard let id = node["id"] as? String,
              let number = node["number"] as? Int,
              let title = node["title"] as? String,
              let urlString = node["url"] as? String,
              let url = URL(string: urlString),
              let createdAtString = node["createdAt"] as? String,
              let authorDict = node["author"] as? [String: Any],
              let author = authorDict["login"] as? String,
              let repoDict = node["repository"] as? [String: Any],
              let repoName = repoDict["name"] as? String else {
            return nil
        }

        let createdAt = ISO8601DateFormatter().date(from: createdAtString) ?? Date()

        var reviewRequestedLogins: [String] = []
        var reviewRequestedTeams: [String] = []
        if let reviewRequests = node["reviewRequests"] as? [String: Any],
           let rrNodes = reviewRequests["nodes"] as? [[String: Any]] {
            for rrNode in rrNodes {
                if let reviewer = rrNode["requestedReviewer"] as? [String: Any] {
                    if let login = reviewer["login"] as? String {
                        reviewRequestedLogins.append(login)
                    } else if let slug = reviewer["slug"] as? String {
                        reviewRequestedTeams.append(slug)
                    }
                }
            }
        }

        var reviews: [Review] = []
        if let reviewsDict = node["reviews"] as? [String: Any],
           let reviewNodes = reviewsDict["nodes"] as? [[String: Any]] {
            for reviewNode in reviewNodes {
                if let reviewAuthor = (reviewNode["author"] as? [String: Any])?["login"] as? String,
                   let stateString = reviewNode["state"] as? String,
                   let verdict = ReviewVerdict(rawValue: stateString) {
                    reviews.append(Review(author: reviewAuthor, verdict: verdict))
                }
            }
        }

        let commentCount = (node["comments"] as? [String: Any])?["totalCount"] as? Int ?? 0

        return PullRequest(
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
            latestReviews: reviews,
            commentCount: commentCount
        )
    }

    // MARK: - HTTP

    private func graphQL(body: String) async throws -> Data {
        try await graphQL(bodyData: Data(body.utf8))
    }

    private func graphQL(bodyData: Data) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GitHubError.httpError(http.statusCode, body)
        }
        return data
    }
}
