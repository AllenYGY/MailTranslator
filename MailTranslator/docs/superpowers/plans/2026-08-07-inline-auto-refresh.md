# Mail Inline Translation Auto-Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically show bilingual message content after translation without manually reselecting the message or crashing Mail.

**Architecture:** Keep the Mail primary-action extension request alive with a non-empty progress view controller. On successful translation, issue one guarded `reloadVisibleMessages` request so Mail calls `decodedMessage` and receives the rewritten MIME data.

**Tech Stack:** Swift, AppKit, MailKit, Foundation, the repository's command-line test harness.

---

### Task 1: Lock refresh lifecycle behavior

**Files:**
- Create: `Sources/Extension/TranslationRefreshCoordinator.swift`
- Modify: `Tests/CoreTests.swift`
- Modify: `test.sh`

- [ ] Add a failing test proving a translation action may request refresh exactly once after success and never after failure.
- [ ] Run `./test.sh` and confirm the lifecycle assertion fails because the coordinator does not exist.
- [ ] Add a lock-protected one-shot coordinator with `consumeRefreshAfterSuccess()` and `markFailed()` behavior.
- [ ] Run `./test.sh` and confirm all core tests pass.

### Task 2: Keep the action request alive

**Files:**
- Modify: `Sources/Extension/PopoverViewController.swift`
- Modify: `Sources/Extension/TranslationStore.swift`
- Modify: `Sources/Extension/SecurityHandler.swift`

- [ ] Add store observation so a presented controller can react to translating, done, and failed states.
- [ ] Replace the static status label with a controller that updates progress while it remains presented.
- [ ] In `primaryActionClicked`, decode and validate context, create the controller, and call the completion handler exactly once before starting translation.
- [ ] Prevent duplicate translation work when the action is clicked repeatedly.
- [ ] Run `./build.sh` and resolve all Swift/AppKit/MailKit compile errors.

### Task 3: Refresh the bilingual body once

**Files:**
- Modify: `Sources/Extension/SecurityHandler.swift`
- Modify: `Sources/Extension/TranslationRefreshCoordinator.swift`

- [ ] Associate a one-shot refresh coordinator with each active action.
- [ ] After rewritten MIME data and cache are saved, call `MEExtensionManager.reloadVisibleMessages` once on the main thread.
- [ ] Log refresh start, success, and failure with the message key privacy-masked.
- [ ] On translation failure, update store state without attempting refresh.
- [ ] Run `./test.sh` and `./build.sh`.

### Task 4: Install and system-test Mail

**Files:**
- No source files unless runtime evidence exposes a defect.

- [ ] Run `./install.sh` to install and enable the newly built extension.
- [ ] In Mail, select a translatable message and click Translate once.
- [ ] Verify the translated paragraphs appear below the source paragraphs without changing message selection.
- [ ] Repeat translation and verify Mail remains running.
- [ ] Inspect unified logs for translation completion, exactly one refresh request, `decodedMessage` after refresh, Mail crashes, and duplicate-principal-object faults.
- [ ] If runtime verification fails, return to the smallest failing lifecycle hypothesis and repeat the test/build/install cycle.
