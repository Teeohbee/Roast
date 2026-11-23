import Foundation
@testable import RoastKit

final class StubGraphQL: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var nodesByAlias: [String: [[String: Any]]] = [:]
    nonisolated(unsafe) static var queries: [String] = []
    private static let lock = NSLock()

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubGraphQL.self]
        return URLSession(configuration: config)
    }

    static func aliases(in query: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"(\w+): search\("#)
        return regex.matches(in: query, range: NSRange(query.startIndex..., in: query)).map {
            String(query[Range($0.range(at: 1), in: query)!])
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let query = Self.query(from: request)
        Self.lock.lock()
        Self.queries.append(query)
        let data = Self.aliases(in: query).reduce(into: [String: Any]()) {
            $0[$1] = ["nodes": Self.nodesByAlias[$1] ?? []]
        }
        Self.lock.unlock()
        let body = try! JSONSerialization.data(withJSONObject: ["data": data])
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func query(from request: URLRequest) -> String {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
        }
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["query"] as? String ?? ""
    }
}

enum FetchPRsTests {
    static func fetchPRs(teammates: [String]) throws -> [PullRequest] {
        let client = GitHubClient(token: "unused", session: StubGraphQL.session())
        nonisolated(unsafe) var result: Result<[PullRequest], Error>!
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            do { result = .success(try await client.fetchPRs(org: "myorg", team: "myteam", teammates: teammates)) }
            catch { result = .failure(error) }
            done.signal()
        }
        done.wait()
        return try result.get()
    }

    static func prNode(id: String, author: String) -> [String: Any] {
        var node = GitHubClientTests.prNode(comments: [], reviews: [])
        node["id"] = id
        node["author"] = ["login": author]
        return node
    }

    static func run() {
        suite("GitHubClient fetchPRs") {
            test("sends each search in its own request") {
                StubGraphQL.queries = []
                StubGraphQL.nodesByAlias = [:]
                _ = try fetchPRs(teammates: ["alice", "carol"])
                try expect(StubGraphQL.queries.count, 4)
                try expect(StubGraphQL.queries.allSatisfy { StubGraphQL.aliases(in: $0).count == 1 }, "a request had more than one search")
            }

            test("merges PRs found by several searches") {
                StubGraphQL.queries = []
                StubGraphQL.nodesByAlias = [
                    "author0": [prNode(id: "PR_A", author: "alice")],
                    "author1": [prNode(id: "PR_C", author: "carol")],
                    "bodyMention": [prNode(id: "PR_A", author: "alice")],
                ]
                let prs = try fetchPRs(teammates: ["alice", "carol"]).sorted { $0.id < $1.id }
                try expect(prs.map(\.id), ["PR_A", "PR_C"])
                try expect(prs[0].bodyMentionsTeam, true)
                try expect(prs[1].bodyMentionsTeam, false)
            }
        }
    }
}
