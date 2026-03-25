# Logs for Beginners

## What is a log?

A log is a line of text that records something a tool or an app just did.

Think of it like a travel diary for software:

- "I started building"
- "I compiled this file"
- "I failed because a permission is missing"

## The three main kinds of logs you will see

### 1. Build logs

These come from `Xcode` or `xcodebuild` while the app is being compiled.

Example:

```text
Compiling CommandFlowApp.swift
Linking CommandFlow
Build complete!
```

Meaning:

- the source files were turned into an app
- the build succeeded
- this does not automatically prove the app behaves correctly

### 2. Runtime logs

These come from the app while it is running.

Examples:

- opening a settings window
- checking a permission
- loading saved preferences

If the app looks broken, runtime logs often explain where the flow stopped.

### 3. System logs

These come from macOS itself.

You can view them in the `Console` app. They are useful when macOS blocks permissions, rejects automation, or reports app crashes.

## Why logs matter

The interface shows the symptom.
The logs often show the reason.

## Good beginner reflex

When something looks wrong, ask:

1. What did I click?
2. What did I expect?
3. What changed on screen?
4. What does the latest log say?

