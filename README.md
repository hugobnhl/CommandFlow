# CommandFlow

Fresh macOS rebuild of CommandFlow in a clean development environment.

## Why this repo exists

The previous version lived inside a mixed-use `Playground` folder and had local app installs and preferences that could interfere with debugging. This repo is the new clean home for the macOS app.

## Tools we use

- `Xcode` to run the macOS app, open SwiftUI previews, archive, and debug.
- `VS Code` to work with Codex, browse files, and manage Git.
- `Git` to track every change.
- `GitHub` for backup and remote collaboration.
- `xcodegen` to keep the Xcode project reproducible from text files.
- `swiftlint` to catch simple issues early.
- `xcbeautify` to make `xcodebuild` logs easier to read.

## Beginner note: what a log is

A log is a text trace of what a tool or an app is doing.

Examples:

- Build log: "Compiling CommandFlowApp.swift"
- Runtime log: "Opening settings window"
- Error log: "Accessibility permission is missing"

Logs matter because the visible bug is often just the symptom. The log is often where the reason appears.

## Project layout

- `CommandFlow/`: source code and app resources
- `docs/`: beginner-friendly notes and workflow docs
- `scripts/`: helper scripts for parallel feature work and cleanup
- `References/`: temporary reference material from the old app while the rebuild is in progress

## Daily workflow

1. Open the folder in `VS Code` for Codex and Git work.
2. Open `CommandFlow.xcodeproj` in `Xcode` to run the app.
3. Work on one feature branch at a time.
4. Use a separate `git worktree` when you want multiple Codex windows in parallel.

## GitHub setup

After logging in with `gh auth login`, you can create and push the private GitHub repository with:

```bash
./scripts/create_github_repo.sh
```
