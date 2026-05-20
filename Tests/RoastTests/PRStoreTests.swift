import Foundation
@testable import RoastKit

enum PRStoreTests {
    static func freshPreferences() -> PreferencesStore {
        let suiteName = "com.roast.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let prefs = PreferencesStore(defaults: defaults)
        prefs.teamSlug = "myorg/myteam"
        return prefs
    }

    static func run() {
        suite("PRStore needsMyReview") {
            test("PR with review requested for current user -> needsMyReview") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    author: "alice",
                    reviewRequestedLogins: ["bob"]
                )
                let result = store.categorise([pr])
                try expect(result.needsMyReview.contains(pr), "expected PR in needsMyReview")
                try expect(result.myPRs.isEmpty, "expected myPRs empty")
                try expect(result.newActivity.isEmpty, "expected newActivity empty")
            }

            test("PR with review requested for team -> needsMyReview") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    author: "alice",
                    reviewRequestedTeams: ["myteam"]
                )
                let result = store.categorise([pr])
                try expect(result.needsMyReview.contains(pr), "expected PR in needsMyReview")
            }

            test("PR with team mentioned in body -> needsMyReview") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    author: "alice",
                    bodyMentionsTeam: true
                )
                let result = store.categorise([pr])
                try expect(result.needsMyReview.contains(pr), "expected PR in needsMyReview")
            }

            test("PR already reviewed by current user -> excluded from needsMyReview") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    author: "alice",
                    reviewRequestedLogins: ["bob"],
                    latestReviews: [Review(author: "bob", verdict: .approved)]
                )
                let result = store.categorise([pr])
                try expect(!result.needsMyReview.contains(pr), "expected PR excluded from needsMyReview")
            }

            test("Deduplication: review requested and body mention -> appears once in needsMyReview") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    author: "alice",
                    reviewRequestedLogins: ["bob"],
                    bodyMentionsTeam: true
                )
                let result = store.categorise([pr])
                try expect(result.needsMyReview.filter { $0 == pr }.count, 1)
            }
        }

        suite("PRStore myPRs") {
            test("PR authored by current user -> myPRs") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(author: "bob")
                let result = store.categorise([pr])
                try expect(result.myPRs.contains(pr), "expected PR in myPRs")
                try expect(!result.needsMyReview.contains(pr), "expected PR not in needsMyReview")
            }

            test("myPRs takes priority over needsMyReview for own PRs") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    author: "bob",
                    reviewRequestedLogins: ["bob"],
                    bodyMentionsTeam: true
                )
                let result = store.categorise([pr])
                try expect(result.myPRs.contains(pr), "expected PR in myPRs")
                try expect(!result.needsMyReview.contains(pr), "expected PR not in needsMyReview")
            }
        }

        suite("PRStore newActivity") {
            test("Participating PR with new comments -> newActivity") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                // Seed initial state with 2 comments
                let prFirst = ModelsTests.makePR(id: "PR_1", author: "alice", commentCount: 2)
                _ = store.categorise([prFirst])
                // Now update with more comments
                let prUpdated = ModelsTests.makePR(id: "PR_1", author: "alice", commentCount: 5)
                let result = store.categorise([prUpdated])
                try expect(result.newActivity.contains(prUpdated), "expected PR in newActivity")
            }

            test("Participating PR with no new comments -> excluded") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(id: "PR_1", author: "alice", commentCount: 3)
                _ = store.categorise([pr])
                // Same comment count
                let prSame = ModelsTests.makePR(id: "PR_1", author: "alice", commentCount: 3)
                let result = store.categorise([prSame])
                try expect(!result.newActivity.contains(prSame), "expected PR not in newActivity")
            }

            test("First-seen PR gets baseline seeded, not shown as newActivity") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(author: "alice", commentCount: 10)
                let result = store.categorise([pr])
                try expect(!result.newActivity.contains(pr), "first-seen PR should not appear in newActivity")
            }

            test("needsMyReview PR not duplicated in newActivity") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                // Seed first
                let prFirst = ModelsTests.makePR(id: "PR_1", author: "alice", reviewRequestedLogins: ["bob"], commentCount: 1)
                _ = store.categorise([prFirst])
                // New comments, but still in needsMyReview
                let prUpdated = ModelsTests.makePR(id: "PR_1", author: "alice", reviewRequestedLogins: ["bob"], commentCount: 5)
                let result = store.categorise([prUpdated])
                try expect(result.needsMyReview.contains(prUpdated), "expected PR in needsMyReview")
                try expect(!result.newActivity.contains(prUpdated), "expected PR not duplicated in newActivity")
            }
        }

        suite("PRStore edge cases") {
            test("Empty input -> empty categories") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let result = store.categorise([])
                try expect(result == .empty, "expected empty categories")
            }
        }

        suite("PRStore badgeCount") {
            test("badgeCount includes needsMyReview count") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr1 = ModelsTests.makePR(id: "PR_1", author: "alice", reviewRequestedLogins: ["bob"])
                let pr2 = ModelsTests.makePR(id: "PR_2", author: "alice", reviewRequestedLogins: ["bob"])
                _ = store.categorise([pr1, pr2])
                try expect(store.badgeCount >= 2, "expected badge count to include needsMyReview")
            }

            test("badgeCount includes newActivity count") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(id: "PR_1", author: "alice", commentCount: 2)
                _ = store.categorise([pr])
                let prUpdated = ModelsTests.makePR(id: "PR_1", author: "alice", commentCount: 5)
                _ = store.categorise([prUpdated])
                try expect(store.badgeCount >= 1, "expected badge count to include newActivity")
            }
        }

        suite("PRStore newCommentCounts") {
            test("newCommentCounts reports delta for activity PRs") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(id: "PR_1", author: "alice", commentCount: 2)
                _ = store.categorise([pr])
                let prUpdated = ModelsTests.makePR(id: "PR_1", author: "alice", commentCount: 5)
                _ = store.categorise([prUpdated])
                try expect(store.newCommentCounts["PR_1"], 3)
            }

            test("newCommentCounts is empty when no new activity") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(id: "PR_1", author: "alice", commentCount: 2)
                _ = store.categorise([pr])
                try expect(store.newCommentCounts.isEmpty, "expected no new comment counts")
            }
        }

        suite("PRStore previousCategorised") {
            test("previousCategorised is updated before setting new categorised") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(author: "bob")
                let first = store.categorise([pr])
                try expect(store.previousCategorised == .empty, "previousCategorised should be empty before first call")
                _ = store.categorise([pr])
                try expect(store.previousCategorised == first, "previousCategorised should hold previous result")
            }
        }

        suite("PRStore markSeen") {
            test("markSeen updates lastSeenCommentCount in preferences") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(id: "PR_42", commentCount: 7)
                store.markSeen(pr)
                try expect(prefs.lastSeenCommentCount(forPR: "PR_42"), 7)
            }

            test("markSeen updates lastSeenVerdict in preferences") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    id: "PR_42",
                    latestReviews: [Review(author: "carol", verdict: .approved)]
                )
                store.markSeen(pr)
                try expect(prefs.lastSeenVerdict(forPR: "PR_42"), .approved)
            }
        }
    }
}
