# Roast

*Had your PR Roasted yet?*

A native macOS menubar app that shows GitHub PRs requiring your attention, scoped to your team.

## Features

- **Two-section menu** - "Needs My Review" and "My PRs"
- **Team-scoped** - Only shows PRs from your GitHub team members
- **CI status** - Green, red, or yellow dot per PR so you know if CI is passing
- **Stale review detection** - PRs return to "Needs My Review" when new commits are pushed after your review
- **New comment indicators** - Blue inline count on any PR with new comments from other people (conversation and inline, bots excluded) since you last clicked it
- **Notifications** - macOS banners for review requests, new commits since your review, verdicts and new comments on your PRs. One per PR per poll; clicking opens the PR and marks it seen
- **Jira integration** - Cmd-click any PR with a ticket reference to open Jira
- **Draft filtering** - Other people's draft PRs are hidden; yours still show in "My PRs"
- **Lightweight** - Pure AppKit, no Electron, no SwiftUI, no dependencies

## Install

Requires macOS 14+ and Xcode Command Line Tools.

```bash
xcode-select --install   # if you haven't already
git clone git@github.com:Teeohbee/Roast.git
cd Roast
./build.sh --install
```

This builds a release binary, signs the bundle and copies `Roast.app` to `/Applications`.

### Signing certificate (one-time)

`build.sh` signs with a self-signed certificate named `Roast Dev`, so macOS sees the same app across rebuilds and keeps its Keychain access. Create it in **Keychain Access → Certificate Assistant → Create a Certificate**:

- Name: `Roast Dev`
- Identity Type: Self-Signed Root
- Certificate Type: Code Signing

It doesn't need to be trusted. Without it, `build.sh` falls back to ad-hoc signing with a warning, and permissions reset on every rebuild. Use a different certificate with `SIGN_IDENTITY="My Cert" ./build.sh`.

The first time Roast reads the GitHub token after a signing change, macOS asks for your keychain password. Click **Always Allow**.

## Setup

On first launch, Settings opens automatically. You need:

1. **GitHub Token** - a [classic PAT](https://github.com/settings/tokens/new) with `read:org`, `repo`, `notifications` scopes
2. **Team** - your GitHub team slug (e.g. `simplybusiness/high-rollers`)
3. **Poll interval** - how often to check GitHub (default 2 minutes)

Roast asks for notification permission on first launch. It must run from an Applications folder (`--install` does this); macOS refuses notifications to apps run from elsewhere. Turn banners off with **Show notifications** in Settings. If macOS has them turned off, Settings says so and links to System Settings.

## How it works

Roast polls GitHub's GraphQL API on a configurable interval, batching multiple search queries into a single request. It fetches:

- Open PRs authored by team members (excluding drafts from other people)
- PRs where the team is requested as reviewer
- PRs mentioning the team in the body (exact match)

PRs from archived repositories are filtered out.

Results are categorised into two sections and diffed against the previous poll to detect changes. PRs you've already approved or requested changes on are hidden unless new commits make your review stale.

The app re-polls automatically on wake from sleep.

Token is stored in macOS Keychain. Preferences in UserDefaults.

## Tests

```bash
swift run RoastTests
```

## Menu bar

| Icon | State |
|------|-------|
| Flame (outlined) | All clear - no PRs need attention |
| Flame (filled) + count | PRs need your attention |
| Flame + ! | Error - check Settings |
