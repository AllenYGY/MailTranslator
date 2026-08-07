# Progressive Translation Cancellation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show progressive bilingual Mail content and provide a safe Stop/Continue action for active translations.

**Architecture:** `TranslationStore` becomes the authoritative per-message state machine and tracks whether Mail has rendered the stop action. A task registry owns one cancellable task per message; the pipeline preserves `CancellationError`; a serialized scheduler coalesces reload requests. `SecurityHandler` translates these state transitions into the existing Mail banner and rewritten MIME.

**Tech Stack:** Swift 5, Foundation concurrency, MailKit, existing shell test harness.

**Repository constraint:** `Sources/` and `Tests/` are currently pre-existing untracked workspace content. Do not stage or commit those files during this plan. The already committed design documents are the only changes safe to commit until project ownership is normalized.

---

## File Structure

- Modify: `Tests/CoreTests.swift` - add deterministic state-machine, registry, pipeline cancellation, and refresh scheduling assertions.
- Modify: `test.sh` - compile newly testable extension lifecycle helpers into the test executable.
- Modify: `Sources/Extension/TranslationStore.swift` - model stable progress, rendered-stop state, continuation, and terminal transitions.
- Create: `Sources/Extension/TranslationTaskRegistry.swift` - own active top-level translation tasks by message key and generation.
- Modify: `Sources/Engine/TranslationPipeline.swift` - rethrow cancellation and stop scheduling new provider batches.
- Modify: `Sources/Providers/OpenAICompatibleEngine.swift` - check cancellation around stream and retry boundaries.
- Modify: `Sources/Providers/VolcengineEngine.swift` - check cancellation around request and result iteration.
- Modify: `Sources/Providers/AppleTranslationEngine.swift` - rethrow cancellation rather than swallowing it as a single-segment failure.
- Replace: `Sources/Extension/TranslationRefreshCoordinator.swift` - serialize, throttle, and coalesce visible-message reload work.
- Modify: `Sources/Extension/SecurityHandler.swift` - render translating/stopped states, distinguish redelivery from Stop, register tasks, request initial/progress/final reloads, and continue missing segments.
- Modify: `Sources/Extension/PopoverViewController.swift` - display stopped state if the details view is ever restored.

## Task 1: Lock Down Message Action State

**Files:**
- Modify: `Tests/CoreTests.swift`
- Modify: `test.sh`
- Modify: `Sources/Extension/TranslationStore.swift`

- [ ] **Step 1: Write failing store-state tests**

Add assertions which establish an initial store entry, mark it translating for three segments, and require the following sequence:

```swift
let store = TranslationStore()
store.stash(key: "message", stash: stash)
expect(store.markTranslating(key: "message", totalSegments: 3, prefilled: [:]), "idle message should start")
expect(store.action(for: "message") == .ignoreRedelivery, "redelivery before banner must be ignored")
store.markCancellationPresented(key: "message")
expect(store.action(for: "message") == .stop, "rendered stop action must allow cancellation")
store.updateProgress(key: "message", translations: [0: "one"], rewritten: rewritten)
store.stop(key: "message")
expect(store.translations(key: "message")[0] == "one", "stopping must preserve completed text")
expect(store.action(for: "message") == .continueTranslation, "stopped message must continue")
```

Also assert a stale generation cannot call `finish` after `stop`, and a fresh continuation does not erase existing translations.

- [ ] **Step 2: Run the core tests and confirm compilation fails**

Run: `./test.sh`

Expected: compilation errors for `totalSegments`, `action(for:)`, `markCancellationPresented`, and `stop`.

- [ ] **Step 3: Introduce explicit state and action types**

In `TranslationStore.swift`, replace batch-count state with segment-count state and add these public types:

```swift
enum State {
    case idle
    case translating(completedSegments: Int, totalSegments: Int, latestRewritten: Data?, cancellationPresented: Bool, generation: UInt)
    case stopped(completedSegments: Int, totalSegments: Int, latestRewritten: Data?, generation: UInt)
    case done(rewritten: Data, generation: UInt)
    case failed(String, latestRewritten: Data?, generation: UInt)
}

enum Action: Equatable {
    case start
    case ignoreRedelivery
    case stop
    case continueTranslation
    case retranslate
    case retry
}
```

Make `markTranslating` return a generation, make progress count `translations.count`, add `markCancellationPresented`, `stop`, `missingIndexes`, and generation-guarded `updateProgress`, `finish`, and `fail`. Existing translations are cleared only by explicit retranslate.

- [ ] **Step 4: Compile testable store code into the harness**

Extend the `swiftc` list in `test.sh` with:

```bash
Sources/Extension/TranslationStore.swift \
Sources/Extension/TranslationTaskRegistry.swift \
Sources/Extension/TranslationRefreshCoordinator.swift
```

The store must remain Foundation-only so it can be tested without the MailKit extension target.

- [ ] **Step 5: Run the core tests and confirm they pass**

Run: `./test.sh`

Expected: `全部测试通过`.

## Task 2: Make Cancellation Reach Providers

**Files:**
- Modify: `Tests/CoreTests.swift`
- Modify: `Sources/Engine/TranslationPipeline.swift`
- Modify: `Sources/Providers/OpenAICompatibleEngine.swift`
- Modify: `Sources/Providers/VolcengineEngine.swift`
- Modify: `Sources/Providers/AppleTranslationEngine.swift`

- [ ] **Step 1: Add a controllable cancellation test engine**

Define an in-test `TranslationEngine` whose first batch suspends until a continuation is cancelled, records started batch indexes under `NSLock`, and throws `CancellationError` after `try Task.checkCancellation()`.

```swift
let task = Task {
    try await TranslationPipeline(engine: engine, target: .zhHans).translate(
        inputs: inputs,
        onSegment: { _, _ in },
        onBatchResult: { _, _, _ in }
    )
}
engine.waitUntilFirstBatchStarts()
task.cancel()
do { _ = try await task.value; expect(false, "cancelled pipeline must throw") }
catch is CancellationError {}
expect(engine.startedBatchCount == 1, "cancellation must prevent scheduling a replacement batch")
```

Run this test from an async test helper invoked by `CoreTests.main`.

- [ ] **Step 2: Run the test and confirm it fails**

Run: `./test.sh`

Expected: cancellation is returned as an ordinary batch failure or further batches start.

- [ ] **Step 3: Preserve `CancellationError` in the pipeline**

Update the child task body and group loop to check cancellation and throw rather than wrap it:

```swift
try Task.checkCancellation()
let results = try await engine.translate(batch: batch, target: target, onSegment: onSegment)
try Task.checkCancellation()
return (batchIndex, results)
```

Use `withThrowingTaskGroup(of: (Int, [Int: String]).self)`. On cancellation call `group.cancelAll()` and rethrow; only non-cancellation errors are accumulated as partial failures. Check cancellation before enqueueing each replacement batch and before each batch callback.

- [ ] **Step 4: Add cancellation checks around provider boundaries**

Use `try Task.checkCancellation()` before and after each `URLSession` await in the OpenAI-compatible and Volcengine engines, before each OpenAI streamed callback, and before each Apple per-segment translation. In Apple translation, rethrow `CancellationError` from the per-segment `catch`; retain current behavior for non-cancellation segment failures.

- [ ] **Step 5: Re-run the core test suite**

Run: `./test.sh`

Expected: `全部测试通过` and the cancellation test completes without hanging.

## Task 3: Add Task Ownership and Reload Coalescing

**Files:**
- Modify: `Tests/CoreTests.swift`
- Create: `Sources/Extension/TranslationTaskRegistry.swift`
- Replace: `Sources/Extension/TranslationRefreshCoordinator.swift`

- [ ] **Step 1: Write failing registry and scheduler tests**

Add deterministic tests for a registry that rejects a second task for the same key, sends cancellation to the registered task, and does not remove a newer task when an older generation completes.

For the scheduler, inject a test executor that records reload starts and manually calls its supplied completion. Assert:

```swift
scheduler.request(.initial)
scheduler.request(.progress)
scheduler.request(.progress)
expect(starts == [.initial], "reloads may not overlap")
completeFirstReload()
advanceClock(by: 1)
expect(starts == [.initial, .progress], "pending progress must coalesce into one trailing reload")
```

Then assert a terminal request is queued immediately after an active reload and does not violate serialization.

- [ ] **Step 2: Run the test suite and confirm missing-type failures**

Run: `./test.sh`

Expected: compilation errors for `TranslationTaskRegistry`, `TranslationRefreshCoordinator.Request`, and injected scheduler executor APIs.

- [ ] **Step 3: Implement `TranslationTaskRegistry`**

Create a Foundation-only lock-protected registry with a generation token:

```swift
final class TranslationTaskRegistry: @unchecked Sendable {
    struct Handle: Equatable { let key: String; let generation: UInt }
    func register(key: String, task: Task<Void, Never>) -> Handle?
    func cancel(key: String, generation: UInt) -> Bool
    func remove(_ handle: Handle)
}
```

`register` refuses an occupied key. `remove` checks its exact handle before removing. `cancel` calls `task.cancel()` only for the matching handle.

- [ ] **Step 4: Implement a serialized scheduler with injected execution**

Give `TranslationRefreshCoordinator` a `request(_:)` API where reasons are `.initial`, `.progress`, and `.terminal`. Internally keep `isReloading`, `pendingReason`, and `lastStart`; coalesce progress requests, select terminal over progress, and start the next request only after its completion closure. Production initialization dispatches to the main queue and calls `MEExtensionManager.reloadVisibleMessages` through a closure supplied by `SecurityHandler`; the helper itself remains MailKit-free and testable.

- [ ] **Step 5: Run all core tests**

Run: `./test.sh`

Expected: `全部测试通过`.

## Task 4: Integrate Progressive Rendering and Stop/Continue

**Files:**
- Modify: `Sources/Extension/SecurityHandler.swift`
- Modify: `Sources/Extension/PopoverViewController.swift`
- Modify: `Tests/CoreTests.swift`

- [ ] **Step 1: Add a failing MIME progression assertion**

Construct a `TranslationStore.Stash` with two segments and assert that a rewritten snapshot containing only index zero renders original segment zero followed by its translation while leaving segment one source unchanged. Then stop, continue using `missingIndexes`, and assert the final snapshot has both translations in source order.

- [ ] **Step 2: Run the core suite and confirm the new store API is required**

Run: `./test.sh`

Expected: fail until the production integration exposes the continuation input selection used by the test.

- [ ] **Step 3: Render state-specific banners in `decodedMessage`**

Map store state to the following exact titles and actions:

```swift
translating -> "正在翻译... \\(completed)/\\(total)", "停止翻译"
stopped     -> "翻译已停止 \\(completed)/\\(total)", "继续翻译"
done        -> "已翻译为<target>（<provider>）", "重新翻译"
failed      -> "翻译失败：<message>", "继续翻译" or "重试"
```

When returning a translating decoded message, call `store.markCancellationPresented(key:)` after deriving its MIME data. This establishes the user-visible boundary before an action can mean Stop.

- [ ] **Step 4: Replace click handling with action dispatch**

In `primaryActionClicked`, query `store.action(for:)`. For `.ignoreRedelivery`, return while keeping the callback open. For `.stop`, transition to stopped, cancel the matching registry handle, and request terminal reload. For start/retry/retranslate/continue, derive inputs from all segments or `store.missingIndexes`, create a generation-bound task, register it before starting, and request initial reload.

Pass the same generation to `runTranslation`. On every batch result, merge into the store, build a partial bilingual MIME snapshot, and request a progress reload. On successful completion, cache only when every segment is translated, finish the matching generation, remove its handle, and request terminal reload. Catch `CancellationError` separately so it cannot overwrite stopped state; ordinary errors call generation-guarded `fail` and terminal reload.

- [ ] **Step 5: Update details-state rendering**

Add a `stopped` branch to `PopoverViewController` that shows `状态：已停止 completed/total`. Update the translating destructure to the new state shape.

- [ ] **Step 6: Run build and tests**

Run: `./test.sh && ./build.sh`

Expected: test output `全部测试通过` followed by `Build OK`.

## Task 5: Install and Verify in Mail

**Files:**
- No source edits unless evidence exposes a regression.

- [ ] **Step 1: Install the signed app and extension**

Run: `./install.sh`

Expected: the current build is installed at `/Applications/MailTranslator.app` and Mail's extension host loads it.

- [ ] **Step 2: Verify immediate feedback and progressive body updates**

Open a sufficiently long translatable email, click Translate once, and verify the banner changes to `正在翻译... 0/N` before the first provider response. Verify translated paragraphs appear directly below source paragraphs while the same Mail row stays selected.

- [ ] **Step 3: Verify Stop and Continue**

Click `停止翻译` after the waiting banner is visible. Verify `翻译已停止 X/N`, partial translations remain, and no new provider batches begin. Click `继续翻译`; verify it completes only missing paragraphs and ends as `重新翻译`.

- [ ] **Step 4: Verify process and reload health**

Record Mail's PID before and after the workflow with `pgrep -x Mail`. Inspect unified logs:

```bash
/usr/bin/log show --last 10m --predicate 'subsystem == "io.github.allenygy.mailtranslator"' --style compact
```

Expected: no Mail exit, no ExtensionKit principal-object fault, no concurrent reload starts, one initial reload, bounded progress reloads, and one terminal reload per action.

- [ ] **Step 5: Re-run final checks**

Run: `./test.sh && ./build.sh && ./install.sh`

Expected: all commands succeed. Record any manual Mail-only limitation in the final report rather than changing the action completion lifecycle.
