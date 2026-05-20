import Foundation
@testable import RoastKit

enum PreferencesStoreTests {
    static func freshDefaults() -> UserDefaults {
        let suiteName = "com.roast.test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    static func run() {
        suite("PreferencesStore defaults") {
            test("default teamSlug is empty") {
                let store = PreferencesStore(defaults: freshDefaults())
                try expect(store.teamSlug, "")
            }

            test("default pollIntervalMinutes is 2") {
                let store = PreferencesStore(defaults: freshDefaults())
                try expect(store.pollIntervalMinutes, 2)
            }
        }

        suite("PreferencesStore set and get") {
            test("set and get teamSlug") {
                let store = PreferencesStore(defaults: freshDefaults())
                store.teamSlug = "myorg/myteam"
                try expect(store.teamSlug, "myorg/myteam")
            }

            test("set and get pollIntervalMinutes") {
                let store = PreferencesStore(defaults: freshDefaults())
                store.pollIntervalMinutes = 5
                try expect(store.pollIntervalMinutes, 5)
            }
        }

        suite("PreferencesStore teamSlug splitting") {
            test("teamSlug splits into org and team") {
                let store = PreferencesStore(defaults: freshDefaults())
                store.teamSlug = "acme/engineers"
                try expect(store.org, "acme")
                try expect(store.teamName, "engineers")
            }

            test("empty teamSlug gives empty org and team") {
                let store = PreferencesStore(defaults: freshDefaults())
                store.teamSlug = ""
                try expect(store.org, "")
                try expect(store.teamName, "")
            }
        }

        suite("PreferencesStore lastSeenCommentCount") {
            test("defaults to nil for unknown PR") {
                let store = PreferencesStore(defaults: freshDefaults())
                let result = store.lastSeenCommentCount(forPR: "PR_999")
                try expect(result == nil, "expected nil for unknown PR")
            }

            test("set and get lastSeenCommentCount") {
                let store = PreferencesStore(defaults: freshDefaults())
                store.setLastSeenCommentCount(7, forPR: "PR_1")
                try expect(store.lastSeenCommentCount(forPR: "PR_1"), 7)
            }
        }

        suite("PreferencesStore lastSeenVerdict") {
            test("defaults to nil for unknown PR") {
                let store = PreferencesStore(defaults: freshDefaults())
                let result = store.lastSeenVerdict(forPR: "PR_999")
                try expect(result == nil, "expected nil for unknown PR")
            }

            test("set and get lastSeenVerdict") {
                let store = PreferencesStore(defaults: freshDefaults())
                store.setLastSeenVerdict(.approved, forPR: "PR_1")
                try expect(store.lastSeenVerdict(forPR: "PR_1"), .approved)
            }
        }

        suite("PreferencesStore persistence") {
            test("values persist across instances sharing same defaults") {
                let defaults = freshDefaults()
                let store1 = PreferencesStore(defaults: defaults)
                store1.teamSlug = "persist/team"
                store1.pollIntervalMinutes = 10
                store1.setLastSeenCommentCount(3, forPR: "PR_42")
                store1.setLastSeenVerdict(.changesRequested, forPR: "PR_42")

                let store2 = PreferencesStore(defaults: defaults)
                try expect(store2.teamSlug, "persist/team")
                try expect(store2.pollIntervalMinutes, 10)
                try expect(store2.lastSeenCommentCount(forPR: "PR_42"), 3)
                try expect(store2.lastSeenVerdict(forPR: "PR_42"), .changesRequested)
            }
        }
    }
}
