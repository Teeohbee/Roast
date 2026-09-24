# Roast

*Had your PR Roasted yet?*

A native macOS menubar app that shows GitHub PRs requiring your attention, scoped to your team.

## Features

- **Two-section menu** - "Needs My Review" and "My PRs"
- **Team-scoped** - PRs by your team members, requested from your team, or mentioning it
- **CI status** - Green, red or yellow dot per PR
- **Stale review detection** - PRs return to "Needs My Review" when new commits land after your review
- **New comment indicators** - Blue count of comments from other people since you last clicked the PR
- **Notifications** - Banners for review requests, verdicts and new comments on your PRs; clicking opens the PR
- **Jira integration** - Cmd-click a PR with a ticket reference to open Jira
- **Draft filtering** - Other people's drafts are hidden; yours still show

| Menu bar icon | State |
|------|-------|
| Flame (outlined) | All clear |
| Flame (filled) + count | PRs need your attention |
| Flame + ! | Error - check Settings |

## Install

Roast is built from source. Requires macOS 14+ and Xcode Command Line Tools (`xcode-select --install`).

**1. Create a signing certificate (one-time).** In **Keychain Access → Certificate Assistant → Create a Certificate**:

- Name: `Roast Dev`
- Identity Type: Self-Signed Root
- Certificate Type: Code Signing

This lets macOS recognise Roast as the same app after every rebuild, so it keeps its Keychain and notification permissions. Keychain Access will show it as untrusted, which is fine.

**2. Build and install.**

```bash
git clone git@github.com:Teeohbee/Roast.git
cd Roast
./build.sh --install
```

Always launch Roast from `/Applications`: macOS refuses notifications to apps run from anywhere else.

**3. First launch.**

- Click **Always Allow** on the keychain prompt (Roast stores its GitHub token there)
- Click **Allow** on the notification prompt
- In Settings, enter a [classic token](https://github.com/settings/tokens/new) with `read:org` and `repo` scopes, and your team slug (e.g. `simplybusiness/high-rollers`)

If no banners ever appear, turn them on in **System Settings → Notifications → Roast**. macOS sometimes records the first answer as off.

**Updating:** `git pull && ./build.sh --install`, then quit and reopen Roast.

## Tests

```bash
swift run RoastTests
```
