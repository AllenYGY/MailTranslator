# LLM Provider Profile Isolation Implementation Plan

> **For agentic workers:** Execute this plan task by task with tests after each behavior change.

**Goal:** Give every OpenAI-compatible provider preset its own API address, API key, and model while migrating existing users without data loss.

**Architecture:** Store profiles in `TranslatorConfig.llmProfiles` keyed by `LLMProviderPreset.rawValue`, with `activeLLMPreset` selecting the profile consumed by `EngineFactory` and the settings UI. Decode the old top-level `openAI` object only as a migration fallback and omit it from new encoded files.

**Tech Stack:** Swift 5, Foundation Codable, AppKit, existing shell-based Swift tests.

### Task 1: Configuration contract

**Files:** `Sources/Core/TranslatorConfig.swift`, `Tests/CoreTests.swift`

- [x] Add failing tests for independent OpenAI/DeepSeek profiles and legacy JSON migration.
- [ ] Add profile storage, active-profile accessors, migration decoding, and new-schema encoding.
- [ ] Run `./test.sh` and confirm the profile tests pass.

### Task 2: Settings profile switching

**Files:** `Sources/App/SettingsViewController.swift`

- [ ] Load the selected profile into the controls at startup.
- [ ] Capture unsaved fields before a preset switch and restore the selected profile afterward.
- [ ] Populate only a new profile's documented default URL; never copy another profile's key or model.
- [ ] Save the active fields plus all previously edited profiles.

### Task 3: Extension and tooling consumers

**Files:** `Sources/Providers/EngineFactory.swift`, `Sources/Extension/Settings.swift`, `Tests/CoreTests.swift`

- [ ] Make translation and environment overrides use `activeLLMProfile`.
- [ ] Preserve the existing Volcengine and Apple provider paths.
- [ ] Add an environment/profile consumer regression assertion.

### Task 4: Delivery verification

**Files:** `README.md`, `test.sh`

- [ ] Document that each preset has isolated credentials.
- [ ] Run `./test.sh`, `./build.sh`, `./install.sh`, code-sign verification, and installed/build hash checks.
- [ ] Physically switch presets and focus the LLM fields in the installed settings app without saving credentials.
