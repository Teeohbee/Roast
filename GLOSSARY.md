# Roast

Which GitHub PRs need your attention, scoped to the team you review for.

## Language

### Reviewing

**Team**:
The GitHub team you review for, set in Settings.
_Avoid_: Org, group

**Teammate**:
A member of the Team other than you.
_Avoid_: Team member, member

**Review Request**:
A request for your review that can be seen on GitHub: one made to you or your Team, or a mention of your Team in the PR description.
_Avoid_: Requested, ask

**Teammate's PR**:
A non-draft PR opened by a Teammate. You're expected to review it by team habit, whether or not anyone asked, and it stays yours to review after other Teammates give their Verdicts.
_Avoid_: Team PR, team member PR

**Needs My Review**:
The PRs that aren't yours, aren't drafts, and are waiting for your review because of a Review Request, a Teammate's PR or a Stale Review.
_Avoid_: Review queue, to review

**Stale Review**:
Your latest Verdict on a PR when commits have landed after it. A review that only left comments has no Verdict, so it can't go stale.
_Avoid_: Outdated review, re-review

**Verdict**:
A reviewer's latest Approved or Changes Requested on a PR. A PR's overall Verdict is Changes Requested if any reviewer's is, otherwise Approved if any reviewer's is.
_Avoid_: Review state, status

**Pending**:
A PR with no Verdict yet.
_Avoid_: Commented, awaiting review

### Your PRs

**My PRs**:
Your own open PRs, including drafts.
_Avoid_: Authored PRs

**Ready to Merge**:
One of My PRs that GitHub says has every review it requires, including code owners, and that GitHub would let you merge now. Approved means it has an approving Verdict but is still blocked, for example by required checks. Review Required means it has an approving Verdict but GitHub still needs another review, such as from a code owner.
_Avoid_: Mergeable, good to go

**Seen**:
When you last opened a PR itself from Roast, from the menu or a notification. Opening its Jira ticket, copying its link or visiting it on GitHub doesn't count.
_Avoid_: Read, viewed, clicked

**New Comments**:
Conversation and inline review comments from people other than you, not bots, added since the PR was last Seen.
_Avoid_: Unread comments, activity

**Recently Merged**:
Your 10 most recently merged PRs in the Team's organisation, ordered by merge time.
_Avoid_: Closed PRs, history

### Menu bar

**Attention Count**:
The number on the menu bar icon: PRs in Needs My Review plus My PRs with New Comments. A new Verdict doesn't add to it.
_Avoid_: Badge, unread count
