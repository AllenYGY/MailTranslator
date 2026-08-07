# Provider Settings and Model Catalog Design

## Goal

Make MailTranslator's settings window clear enough to configure without prior knowledge, while allowing any OpenAI-compatible provider to expose its own API address and selectable model catalog.

## Recommended Direction

Use one generic OpenAI-compatible provider implementation rather than separate networking engines for each LLM vendor. A provider preset only supplies a known API base URL and display name; users may always choose Custom and edit the URL. Translation and model discovery both consume the same saved base URL and API key.

This keeps compatibility broad, avoids vendor SDK dependencies, and does not prevent future provider-specific authentication adapters.

## Settings Layout

The window uses a quiet macOS utility layout with three stable regions:

1. A compact header with the app icon, title, extension status guidance, and target language.
2. A segmented translation-engine control followed by one dynamic configuration panel. Only the selected provider's controls are visible.
3. A fixed footer containing inline status, Test Connection, and the primary Save button.

The OpenAI-compatible panel contains:

- Service preset: OpenAI, DeepSeek, Kimi, Alibaba DashScope, Volcengine Ark, Ollama, or Custom.
- API address: always visible and editable.
- API key: secure input; optional for local endpoints.
- Model: editable combo box populated from the provider's model catalog.
- Refresh Models: icon-and-text command next to the model control.
- Inline model status: loading spinner, model count on success, or a concise recoverable error.

The model combo box remains editable even after a catalog is loaded. Providers without a compatible model-list endpoint therefore remain usable.

The Volcengine machine-translation panel contains AK and SK fields. The Apple panel contains a concise local-processing status and no credential controls.

## Model Catalog Architecture

`APIEndpoint` owns endpoint normalization. It derives both `chat/completions` and `models` URLs from any of these inputs:

- A version base URL such as `https://api.example.com/v1`
- A chat endpoint such as `https://api.example.com/v1/chat/completions`
- A model endpoint such as `https://api.example.com/v1/models`

`OpenAIModelCatalog` owns request construction, authentication, HTTP validation, JSON decoding, deduplication, and sorting. It accepts the standard OpenAI response shape:

```json
{"object":"list","data":[{"id":"model-a"},{"id":"model-b"}]}
```

The catalog sends `Authorization: Bearer <key>` only when a key is present. Remote HTTP remains rejected; localhost and private IPv4 HTTP retain the existing development exception.

## State and Data Flow

1. Loading settings selects the saved provider and preset inferred from its URL.
2. Changing a preset fills its recommended API URL but does not overwrite the API key.
3. Refresh Models cancels any previous catalog task, validates the URL, disables the refresh control, and starts the spinner.
4. Success replaces the combo-box suggestions, preserves the currently selected model when still available, and otherwise selects the first returned model only when the field is empty.
5. Failure preserves the current manual model and displays a retryable error.
6. Save validates the active provider, writes the same `TranslatorConfig` format, and remains immediately visible to the Mail extension.

## Error Handling

- Invalid or insecure API URLs fail before network access.
- Non-2xx responses surface the status code plus a short server message.
- Empty or malformed model responses display a provider-compatibility message and leave manual entry enabled.
- A superseded fetch is cancelled and cannot overwrite newer UI state.
- Test Connection and Fetch Models have independent progress states and cannot launch duplicate concurrent requests.

## Testing

Unit tests cover endpoint derivation, authorization headers, model-list parsing, ordering, deduplication, empty lists, and HTTP error text. Existing translation tests remain unchanged.

Build verification compiles both architectures. Manual system verification installs the app, checks provider switching, fetches models from a deterministic local OpenAI-compatible fixture server, selects a model, saves, relaunches, and confirms persistence.

## Scope

This iteration does not add vendor-specific OAuth, organization/project headers, arbitrary custom headers, or multiple saved LLM profiles. Those require a separate credential/profile design. Manual model entry is the compatibility fallback for providers that do not implement `GET /models`.
