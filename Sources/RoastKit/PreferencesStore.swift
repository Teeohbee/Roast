import Foundation

public final class PreferencesStore {
    private let defaults: UserDefaults

    private enum Key {
        static let teamSlug = "roast.teamSlug"
        static let pollIntervalMinutes = "roast.pollIntervalMinutes"
        static let lastSeenCommentCounts = "roast.lastSeenCommentCounts"
        static let lastSeenVerdicts = "roast.lastSeenVerdicts"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var teamSlug: String {
        get { defaults.string(forKey: Key.teamSlug) ?? "" }
        set { defaults.set(newValue, forKey: Key.teamSlug) }
    }

    public var pollIntervalMinutes: Int {
        get {
            let stored = defaults.integer(forKey: Key.pollIntervalMinutes)
            return stored == 0 ? 2 : stored
        }
        set { defaults.set(newValue, forKey: Key.pollIntervalMinutes) }
    }

    public var org: String {
        let parts = teamSlug.split(separator: "/", maxSplits: 1)
        return parts.count >= 1 ? String(parts[0]) : ""
    }

    public var teamName: String {
        let parts = teamSlug.split(separator: "/", maxSplits: 1)
        return parts.count >= 2 ? String(parts[1]) : ""
    }

    public func lastSeenCommentCount(forPR prID: String) -> Int? {
        let dict = defaults.dictionary(forKey: Key.lastSeenCommentCounts) as? [String: Int] ?? [:]
        return dict[prID]
    }

    public func setLastSeenCommentCount(_ count: Int, forPR prID: String) {
        var dict = defaults.dictionary(forKey: Key.lastSeenCommentCounts) as? [String: Int] ?? [:]
        dict[prID] = count
        defaults.set(dict, forKey: Key.lastSeenCommentCounts)
    }

    public func lastSeenVerdict(forPR prID: String) -> ReviewVerdict? {
        let dict = defaults.dictionary(forKey: Key.lastSeenVerdicts) as? [String: String] ?? [:]
        guard let raw = dict[prID] else { return nil }
        return ReviewVerdict(rawValue: raw)
    }

    public func setLastSeenVerdict(_ verdict: ReviewVerdict, forPR prID: String) {
        var dict = defaults.dictionary(forKey: Key.lastSeenVerdicts) as? [String: String] ?? [:]
        dict[prID] = verdict.rawValue
        defaults.set(dict, forKey: Key.lastSeenVerdicts)
    }
}
