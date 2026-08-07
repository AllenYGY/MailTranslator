# Provider Settings and Model Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a polished macOS settings window with editable provider API URLs and fetchable, selectable OpenAI-compatible model lists.

**Architecture:** Extend `APIEndpoint` to derive endpoint families and introduce a focused `OpenAIModelCatalog` network client. Keep provider presets and AppKit presentation in the app target, while preserving the existing shared `TranslatorConfig` contract used by the Mail extension.

**Tech Stack:** Swift 5, AppKit, Foundation URLSession, existing shell-based Swift test harness.

---

### Task 1: Endpoint and Model Catalog Contract

**Files:**
- Modify: `Tests/CoreTests.swift`
- Modify: `Sources/Core/APIEndpoint.swift`
- Create: `Sources/Providers/OpenAIModelCatalog.swift`

- [ ] Add failing tests for deriving `/chat/completions` and `/models` from base, chat, and model URLs.
- [ ] Run `./test.sh` and confirm the new model endpoint assertions fail because the API does not exist.
- [ ] Implement endpoint-family normalization without weakening the existing HTTP security rule.
- [ ] Add failing tests for decoding, sorting, deduplicating, and rejecting empty OpenAI model lists.
- [ ] Implement `OpenAIModelCatalog` response parsing and localized errors.
- [ ] Run `./test.sh` and confirm all endpoint and parser tests pass.

### Task 2: Request Construction and Network Errors

**Files:**
- Modify: `Tests/CoreTests.swift`
- Modify: `Sources/Providers/OpenAIModelCatalog.swift`

- [ ] Add failing tests showing the request uses `GET`, sends Bearer authorization only for non-empty keys, and targets the derived models URL.
- [ ] Implement deterministic request construction.
- [ ] Add failing tests for non-2xx and malformed/empty response error messages.
- [ ] Implement async URLSession fetching with bounded timeout, cancellation, and short server error bodies.
- [ ] Run `./test.sh` and confirm all catalog tests pass.

### Task 3: Provider Presets and Dynamic Settings UI

**Files:**
- Create: `Sources/App/LLMProviderPreset.swift`
- Rewrite: `Sources/App/main.swift`

- [ ] Add provider presets for OpenAI, DeepSeek, Kimi, Alibaba DashScope, Volcengine Ark, Ollama, and Custom.
- [ ] Build a stable header, segmented provider control, dynamic provider panel, and fixed footer using AppKit constraints.
- [ ] Replace the model text field with an editable `NSComboBox` and add Refresh Models plus a compact progress indicator.
- [ ] Preserve current configuration loading, validation, save, paste/edit menu support, and Test Connection behavior.
- [ ] Ensure provider switching changes only the visible panel and does not discard values entered in other panels.
- [ ] Compile the app via `./build.sh` and resolve all Swift/AppKit warnings or errors.

### Task 4: Model Fetch Interaction

**Files:**
- Modify: `Sources/App/main.swift`

- [ ] Wire Refresh Models to cancel stale work and read the current URL/key fields.
- [ ] Disable only conflicting model controls while loading and show a spinning progress indicator.
- [ ] Populate and sort model suggestions on success while preserving manual input.
- [ ] Keep the current model untouched on failure and show a retryable inline message.
- [ ] Infer the service preset when loading a previously saved known URL.
- [ ] Run `./test.sh` and `./build.sh`.

### Task 5: Install and System Verification

**Files:**
- Modify: `README.md`

- [ ] Document service presets, custom URLs, model fetching, and manual fallback.
- [ ] Start a deterministic local fixture implementing `GET /v1/models` and `POST /v1/chat/completions`.
- [ ] Install the new build with `./install.sh`.
- [ ] Verify provider switching, loading animation, model population, manual model entry, save, relaunch persistence, and connection testing in the real app.
- [ ] Run `./test.sh`, `./build.sh`, `codesign --verify --deep --strict --verbose=2 /Applications/MailTranslator.app`, and compare installed/build extension hashes.
