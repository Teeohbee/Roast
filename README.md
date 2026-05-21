# Roast

A native macOS menubar app that shows GitHub PRs requiring your attention, scoped to your team.

## Features

- **Three-section menu** - "Needs My Review", "My PRs", and "New Activity" so you know exactly what needs doing
- **Team-scoped** - Filters by GitHub team membership, review requests, and body mentions
- **macOS notifications** - Review requests, approvals, changes requested, new comments
- **Draft labels** - Draft PRs clearly marked in the menu
- **Lightweight** - Pure AppKit, no Electron, no SwiftUI, no dependencies

## Install

Requires macOS 14+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh --install
```

This builds a release binary and copies `Roast.app` to `/Applications`.

To build without installing:

```bash
./build.sh
```

## Setup

On first launch, Settings opens automatically. You need:

1. **GitHub Token** - a classic PAT with `read:org`, `repo`, `notifications` scopes
2. **Team** - your GitHub team slug (e.g. `simplybusiness/high-rollers`)
3. **Poll interval** - how often to check GitHub (default 2 minutes)

## How it works

Roast polls GitHub's GraphQL API on a configurable interval, batching multiple search queries into a single request. It fetches:

- Open PRs authored by team members
- PRs where the team is requested as reviewer
- PRs mentioning the team in the body

Results are categorised into three buckets, diffed against the previous poll to detect changes, and delivered as macOS notifications when something new arrives. If 5+ events land in one cycle, they're collapsed into a single summary notification.

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
