# Original View Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch completed Mail translations reversibly between original MIME and bilingual MIME without provider work.

**Architecture:** `TranslationStore` owns display mode and single-use presentation tokens. A Codable context carries the advertised action to MailKit. `SecurityHandler` validates it, renders bytes, and calls one extension-wide refresh coordinator.

**Tech Stack:** Swift 5, Foundation, MailKit, executable assertions in `Tests/CoreTests.swift`.

---

### Task 1: Make banner actions presentation-safe

**Files:**
- Create: `Sources/Extension/TranslationActionContext.swift`
- Modify: `Sources/Extension/TranslationStore.swift`
- Modify: `Tests/CoreTests.swift`
- Modify: `test.sh`

- [ ] **Step 1: Write the failing test**

Append to the TranslationStore tests:

```swift
expect(store.finish(key: "message", rewritten: Data("bilingual".utf8)), "fixture completes")
let presentation = store.present(key: "message", action: .showOriginal)!
expect(presentation.displayMode == .bilingual, "complete mail begins bilingual")
expect(store.resolveAction(key: "message", token: presentation.token, action: .showOriginal) == .showOriginal, "advertised action accepts")
expect(store.toggleOriginalView(key: "message", token: presentation.token), "original toggle succeeds")
expect(store.displayMode(for: "message") == .original, "original view is selected")
expect(store.translations(key: "message")[0] == "第一段", "toggle preserves translations")
expect(store.resolveAction(key: "message", token: presentation.token, action: .showOriginal) == nil, "old context rejects")
let context = TranslationActionContext(key: "message", token: 42, action: .showBilingual)
expect(TranslationActionContext(data: context.dataRepresentation) == context, "context round trips")
```

- [ ] **Step 2: Verify RED**

Run: `./test.sh`

Expected: compile errors for the missing context and store APIs.

- [ ] **Step 3: Implement minimal state and context**

Create this value type:

```swift
struct TranslationActionContext: Codable, Equatable {
    enum Action: String, Codable { case start, stop, continueTranslation, retranslate, retry, showOriginal, showBilingual }
    let key: String; let token: UInt; let action: Action
    var dataRepresentation: Data { (try? JSONEncoder().encode(self)) ?? Data() }
    init?(data: Data) { guard let value = try? JSONDecoder().decode(Self.self, from: data) else { return nil }; self = value }
    init(key: String, token: UInt, action: Action) { self.key = key; self.token = token; self.action = action }
}
```

Add `DisplayMode { case bilingual, original }`, a `Presentation`, display mode, and active token/action to store entries. Under the existing lock implement `present`, `resolveAction`, `toggleOriginalView`, and `displayMode(for:)`. Presenting mints a new token; resolving consumes only an exact token/action; toggling only works for a complete state and consumed view action. Translation start/reset/finish clears active presentation and selects bilingual. Add the source file to `test.sh`.

- [ ] **Step 4: Verify GREEN**

Run: `./test.sh`

Expected: exit code 0 and `全部测试通过`.

- [ ] **Step 5: Commit**

Commit `TranslationActionContext.swift`, `TranslationStore.swift`, `CoreTests.swift`, and `test.sh` using the Lore protocol. Record stale Mail action redelivery as the constraint and message-key-only context as rejected.

### Task 2: Reserve translation tasks before launching providers

**Files:**
- Modify: `Sources/Extension/TranslationTaskRegistry.swift`
- Modify: `Tests/CoreTests.swift`

- [ ] **Step 1: Write the failing test**

Add before the registry tests:

```swift
let reserved = registry.reserve(key: "reserved", generation: 99)!
expect(registry.handle(for: "reserved") == reserved, "reservation is visible before task creation")
expect(registry.cancelReservation(reserved), "reservation cancels before task creation")
expect(!registry.attach(Task {}, to: reserved), "late task cannot attach to cancelled reservation")
```

- [ ] **Step 2: Verify RED**

Run: `./test.sh`

Expected: compile errors for `reserve`, `attach`, and `cancelReservation`.

- [ ] **Step 3: Implement reservation API**

Store `task: Task<Void, Never>?` and `cancelled: Bool` in registry entries. `reserve(key:generation:)` creates a task-less entry; `attach(_:to:)` only accepts the exact uncancelled handle and cancels rejected tasks; `cancelReservation(_:)` marks an entry cancelled and cancels its task when attached. Keep `remove` identity-guarded. Reimplement legacy `register` by reserve then attach.

- [ ] **Step 4: Verify GREEN**

Run: `./test.sh`

Expected: exit code 0 and `全部测试通过`.

- [ ] **Step 5: Commit**

Commit the registry and test with a Lore record rejecting `Task.yield` as a lifecycle-ordering mechanism.

### Task 3: Integrate original rendering and global refresh serialization

**Files:**
- Modify: `Sources/Extension/SecurityHandler.swift`
- Modify: `Sources/Extension/TranslationRefreshCoordinator.swift`
- Modify: `Tests/CoreTests.swift`
- Modify: `test.sh`

- [ ] **Step 1: Write the failing scheduler regression test**

Use the existing manual executor:

```swift
refreshCoordinator.request(.initial)
refreshCoordinator.request(.terminal)
expect(refreshExecutor.starts == [.initial], "global Mail reload does not overlap")
refreshExecutor.completeNext()
expect(refreshExecutor.starts == [.initial, .terminal], "terminal reload follows the first reload")
```

- [ ] **Step 2: Verify RED**

Run: `./test.sh`

Expected: the per-message architecture provides no shared-owner seam or demonstrates that cross-message reloads can overlap.

- [ ] **Step 3: Implement the Mail adapter**

Replace SecurityHandler's coordinator dictionary with one lazy `TranslationRefreshCoordinator` whose executor calls `MEExtensionManager.reloadVisibleMessages`. Change decoded-message rendering to mint `TranslationActionContext` and encode it into the Mail context. A complete `.original` state renders `stash.original` with `查看双语译文`; bilingual renders rewritten bytes with `只看原文`.

Decode and validate context in `primaryActionClicked`. View actions only toggle mode and request terminal refresh. They create no engine or task. Keep task actions unchanged after validation. Reserve a task before creating it, request initial refresh, attach it, and remove it via its reserved handle. Preserve the open primary completion handler and nil extension view controller.

- [ ] **Step 4: Verify GREEN and extension build**

Run: `./test.sh && ./build.sh`

Expected: both exit 0; build reports `Build OK:` and strict signing validation.

- [ ] **Step 5: Commit**

Commit the Mail integration with Lore trailers: global `reloadVisibleMessages` is the constraint; per-message reload coordinators are rejected; all reloads must flow through the extension-wide coordinator.

### Task 4: Install and validate lifecycle

**Files:**
- Modify: `install.sh` only if verification exposes a deterministic install defect.

- [ ] **Step 1: Run automated verification**

Run: `./test.sh && ./build.sh && ./install.sh`

Expected: exit code 0 and strict signature validation for `/Applications/MailTranslator.app`.

- [ ] **Step 2: Manually validate Mail**

Open a completed translation, click `只看原文` then `查看双语译文`, and verify no provider request or lost translations. Start a fresh translation, validate `正在翻译...` and `停止翻译`, inspect reload logs, and confirm Mail's PID is unchanged.

- [ ] **Step 3: Commit an installation adjustment only if one was necessary**

Do not commit `install.sh` when unchanged. Any needed installation commit uses the Lore protocol and records the signature condition found during verification.
