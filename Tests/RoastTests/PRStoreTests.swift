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
                try expect(result.needsMyReview.count, 1)
                try expect(result.needsMyReview[0].id, pr.id)
            }

            test("PR with review requested for team -> needsMyReview") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    author: "alice",
                    reviewRequestedTeams: ["myteam"]
                )
                let result = store.categorise([pr])
                try expect(result.needsMyReview.count, 1)
            }

            test("PR with team mentioned in body -> needsMyReview") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    author: "alice",
                    bodyMentionsTeam: true
                )
                let result = store.categorise([pr])
                try expect(result.needsMyReview.count, 1)
            }

            test("PR excluded after approval") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    author: "alice",
                    reviewRequestedLogins: ["bob"],
                    latestReviews: [Review(author: "bob", verdict: .approved)]
                )
                let result = store.categorise([pr])
                try expect(result.needsMyReview.count, 0)
            }

            test("PR with only a comment review still shows in needsMyReview") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    author: "alice",
                    reviewRequestedLogins: ["bob"],
                    latestReviews: [Review(author: "bob", verdict: .commented)]
                )
                let result = store.categorise([pr])
                try expect(result.needsMyReview.count, 1)
            }

            test("Draft PR excluded from needsMyReview") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    author: "alice",
                    reviewRequestedLogins: ["bob"],
                    isDraft: true
                )
                let result = store.categorise([pr])
                try expect(result.needsMyReview.count, 0)
            }

            test("Own PR goes to myPRs not needsMyReview") {
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

        suite("PRStore needsMyReview - team member authored") {
            test("PR authored by team member goes to needsMyReview") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(author: "alice")
                let result = store.categorise([pr], teamMembers: ["alice", "bob", "carol"])
                try expect(result.needsMyReview.count, 1)
            }

            test("PR authored by team member excluded if approved") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(
                    author: "alice",
                    latestReviews: [Review(author: "bob", verdict: .approved)]
                )
                let result = store.categorise([pr], teamMembers: ["alice", "bob"])
                try expect(result.needsMyReview.count, 0)
            }

            test("PR authored by non-team-member without review request excluded") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(author: "stranger")
                let result = store.categorise([pr], teamMembers: ["alice", "bob"])
                try expect(result.needsMyReview.count, 0)
            }
        }

        suite("PRStore stale reviews") {
            test("stale review puts PR back in needsMyReview") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let reviewDate = Date(timeIntervalSince1970: 1_700_000_000)
                let commitDate = Date(timeIntervalSince1970: 1_700_001_000)
                let pr = ModelsTests.makePR(
                    author: "alice",
                    reviewRequestedLogins: ["bob"],
                    latestReviews: [Review(author: "bob", verdict: .approved, submittedAt: reviewDate)],
                    lastCommitDate: commitDate
                )
                let result = store.categorise([pr])
                try expect(result.needsMyReview.count, 1)
            }

            test("non-stale review keeps PR excluded") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let commitDate = Date(timeIntervalSince1970: 1_700_000_000)
                let reviewDate = Date(timeIntervalSince1970: 1_700_001_000)
                let pr = ModelsTests.makePR(
                    author: "alice",
                    reviewRequestedLogins: ["bob"],
                    latestReviews: [Review(author: "bob", verdict: .approved, submittedAt: reviewDate)],
                    lastCommitDate: commitDate
                )
                let result = store.categorise([pr])
                try expect(result.needsMyReview.count, 0)
            }
        }

        suite("PRStore newCommentCount") {
            test("new comments detected after baseline seeded") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(id: "PR_1", author: "bob", commentCount: 2)
                _ = store.categorise([pr])
                let prUpdated = ModelsTests.makePR(id: "PR_1", author: "bob", commentCount: 5)
                _ = store.categorise([prUpdated])
                try expect(store.newCommentCount(for: prUpdated), 3)
            }

            test("no new comments when count unchanged") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(id: "PR_1", author: "bob", commentCount: 5)
                _ = store.categorise([pr])
                try expect(store.newCommentCount(for: pr), 0)
            }

            test("first-seen PR has zero new comments") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(author: "bob", commentCount: 10)
                _ = store.categorise([pr])
                try expect(store.newCommentCount(for: pr), 0)
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

            test("badgeCount includes myPRs with new comments") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(id: "PR_1", author: "bob", commentCount: 2)
                _ = store.categorise([pr])
                let prUpdated = ModelsTests.makePR(id: "PR_1", author: "bob", commentCount: 5)
                _ = store.categorise([prUpdated])
                try expect(store.badgeCount >= 1, "expected badge count to include myPRs with new comments")
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

            test("markSeen clears new comment count") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(id: "PR_1", author: "bob", commentCount: 2)
                _ = store.categorise([pr])
                let prUpdated = ModelsTests.makePR(id: "PR_1", author: "bob", commentCount: 5)
                _ = store.categorise([prUpdated])
                try expect(store.newCommentCount(for: prUpdated), 3)
                store.markSeen(prUpdated)
                try expect(store.newCommentCount(for: prUpdated), 0)
            }
        }
    }

    static func runDiffTests() {
        suite("PRStore detectChanges - review requests") {
            test("new review request detected") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(author: "alice", reviewRequestedLogins: ["bob"])
                _ = store.categorise([])
                _ = store.categorise([pr])
                let events = store.detectChanges()
                try expect(events.count, 1)
                try expect(events[0] == .reviewRequested(pr: pr), "expected reviewRequested event")
            }

            test("no event when review request already existed") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(author: "alice", reviewRequestedLogins: ["bob"])
                _ = store.categorise([pr])
                _ = store.categorise([pr])
                let events = store.detectChanges()
                let reviewEvents = events.filter {
                    if case .reviewRequested = $0 { return true }
                    return false
                }
                try expect(reviewEvents.isEmpty, "expected no reviewRequested events for existing request")
            }
        }

        suite("PRStore detectChanges - verdicts on my PRs") {
            test("new approval detected on my PR") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let prBefore = ModelsTests.makePR(id: "PR_1", author: "bob", latestReviews: [])
                let prAfter = ModelsTests.makePR(
                    id: "PR_1",
                    author: "bob",
                    latestReviews: [Review(author: "carol", verdict: .approved)]
                )
                _ = store.categorise([prBefore])
                _ = store.categorise([prAfter])
                let events = store.detectChanges()
                try expect(events.count, 1)
                try expect(events[0] == .approved(pr: prAfter, reviewer: "carol"), "expected approved event")
            }

            test("changes requested detected on my PR") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let prBefore = ModelsTests.makePR(id: "PR_1", author: "bob", latestReviews: [])
                let prAfter = ModelsTests.makePR(
                    id: "PR_1",
                    author: "bob",
                    latestReviews: [Review(author: "carol", verdict: .changesRequested)]
                )
                _ = store.categorise([prBefore])
                _ = store.categorise([prAfter])
                let events = store.detectChanges()
                try expect(events.count, 1)
                try expect(events[0] == .changesRequested(pr: prAfter, reviewer: "carol"), "expected changesRequested event")
            }
        }

        suite("PRStore detectChanges - no false positives") {
            test("no events when nothing changed") {
                let prefs = freshPreferences()
                let store = PRStore(preferences: prefs, currentUser: "bob")
                let pr = ModelsTests.makePR(id: "PR_1", author: "alice", reviewRequestedLogins: ["bob"], commentCount: 3)
                _ = store.categorise([pr])
                _ = store.categorise([pr])
                let events = store.detectChanges()
                try expect(events.isEmpty, "expected no events when nothing changed")
            }
        }
    }
}
