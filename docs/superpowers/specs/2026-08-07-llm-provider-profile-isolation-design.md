# LLM Provider Profile Isolation

## Goal

Keep the API address, API key, and model selection independent for every LLM provider preset.

## Design

`TranslatorConfig` stores OpenAI-compatible settings in `llmProfiles`, keyed by `LLMProviderPreset.rawValue`, and stores the selected preset in `activeLLMPreset`. The extension reads only `activeLLMProfile`, so translation and model discovery use the credentials belonging to the selected provider.

The legacy top-level `openAI` object remains accepted by `Codable` decoding. On load, it is mapped to the preset matching its base URL, or to Custom when no preset matches. New saves omit the legacy field so credentials are not duplicated.

The settings controller keeps unsaved edits for the current profile before switching presets, then loads the selected profile. A newly selected preset receives its documented base URL only when its profile has no address; its API key and model are never copied from another profile.

## Scope

This supports one saved profile per preset. Multiple accounts for one provider and provider-specific authentication beyond the existing fields remain out of scope.

## Verification

Core tests cover profile isolation, legacy migration, and omission of the legacy field. The settings hit-test regression remains part of `test.sh`; full tests, universal build, installation, and a physical settings-window check verify delivery.
