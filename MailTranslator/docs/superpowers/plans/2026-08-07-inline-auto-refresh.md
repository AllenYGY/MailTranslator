# Mail Inline Translation Auto-Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically show bilingual message content after translation without manually reselecting the message or crashing Mail.

**Architecture:** Keep the Mail primary-action extension request open, suppress its duplicate callbacks with a per-message cooldown gate, and issue one guarded `reloadVisibleMessages` request after success so Mail calls `decodedMessage` and receives the rewritten MIME data.

**Tech Stack:** Swift, AppKit, MailKit, Foundation, the repository's command-line test harness.

---

### Task 1: Lock refresh lifecycle behavior

**Files:**
- Create: `Sources/Extension/TranslationRefreshCoordinator.swift`
- Modify: `Tests/CoreTests.swift`
- Modify: `test.sh`

- [x] Add failing tests proving refresh is one-shot and duplicate action callbacks are suppressed.
- [x] Run `./test.sh` and confirm each test fails because its lifecycle helper does not exist.
- [x] Add lock-protected refresh and action gate helpers.
- [x] Run `./test.sh` and confirm all core tests pass.

### Task 2: Keep the action request alive

**Files:**
- Modify: `Sources/Extension/PopoverViewController.swift`
- Modify: `Sources/Extension/TranslationStore.swift`
- Modify: `Sources/Extension/SecurityHandler.swift`

- [x] System-test non-empty completion and prove it exits Mail on macOS 26.5.
- [x] Keep the primary-action request open as the stable lifecycle fallback.
- [x] Prevent duplicate translation work when Mail redelivers the open action.
- [x] Run `./build.sh` and resolve all Swift/AppKit/MailKit compile errors.

### Task 3: Refresh the bilingual body once

**Files:**
- Modify: `Sources/Extension/SecurityHandler.swift`
- Modify: `Sources/Extension/TranslationRefreshCoordinator.swift`

- [x] Associate a one-shot refresh coordinator with each active action.
- [x] After rewritten MIME data and cache are saved, call `MEExtensionManager.reloadVisibleMessages` once on the main thread.
- [x] Log refresh start, success, and failure with the message key privacy-masked.
- [x] On translation failure, update store state without attempting refresh.
- [x] Run `./test.sh` and `./build.sh`.

### Task 4: Install and system-test Mail

**Files:**
- No source files unless runtime evidence exposes a defect.

- [x] Run `./install.sh` to install and enable the newly built extension.
- [x] In Mail, select a translatable message and click Translate once.
- [x] Verify the translated paragraphs appear below the source paragraphs without changing message selection.
- [x] Repeat translation and verify Mail remains running.
- [x] Inspect unified logs for translation completion, exactly one refresh request, and `decodedMessage` after refresh.
- [x] Use runtime evidence to reject the non-empty completion path and verify the stable open-request fallback.
