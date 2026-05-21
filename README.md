# Roast

A native macOS menubar app that shows GitHub PRs requiring your attention, scoped to your team.

## Features

- **Three-section menu** - "Needs My Review", "My PRs", and "New Activity"
- **Team-scoped** - Only shows PRs from your GitHub team members
- **CI status** - Green, red, or yellow dot per PR so you know if CI is passing
- **macOS notifications** - Review requests, approvals, changes requested, new comments
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

This builds a release binary and copies `Roast.app` to `/Applications`.

Because the app isn't code-signed, macOS will ask for your keychain password the first time Roast reads or writes the GitHub token. Click **Always Allow** and it won't ask again unless you rebuild.

## Setup

On first launch, Settings opens automatically. You need:

1. **GitHub Token** - a [classic PAT](https://github.com/settings/tokens/new) with `read:org`, `repo`, `notifications` scopes
2. **Team** - your GitHub team slug (e.g. `simplybusiness/high-rollers`)
3. **Poll interval** - how often to check GitHub (default 2 minutes)

## How it works

Roast polls GitHub's GraphQL API on a configurable interval, batching multiple search queries into a single request. It fetches:

- Open PRs authored by team members (excluding drafts from other people)
- PRs where the team is requested as reviewer
- PRs mentioning the team in the body (exact match)

PRs from archived repositories are filtered out.

Results are categorised into three buckets, diffed against the previous poll to detect changes, and delivered as macOS notifications when something new arrives. If 5+ events land in one cycle, they're collapsed into a single summary notification.

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
