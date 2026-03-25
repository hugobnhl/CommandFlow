# Parallel feature workflow with git worktree

`git worktree` lets one Git repository appear in multiple folders at the same time.

Why this helps:

- one Codex window can work on feature A
- another Codex window can work on feature B
- both still belong to the same repository
- you avoid messy manual copies of the project folder

## Example

```bash
git worktree add ../CommandFlow-feature-settings -b codex/settings-rebuild
```

This creates:

- a new branch: `codex/settings-rebuild`
- a new folder next to the main repo

## Rule of thumb

- one feature = one branch
- one active Codex window = one worktree

