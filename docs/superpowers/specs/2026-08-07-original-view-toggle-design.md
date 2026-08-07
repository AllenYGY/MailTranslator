# Original View Toggle Design

## Goal

Let a reader temporarily view an email exactly as received after translation,
then return to the existing progressive bilingual view without a new provider
request, cache lookup, or loss of completed translations.

## Product Behavior

- Before translation completes, the primary banner action keeps its current
  task-oriented meaning: `翻译`, `停止翻译`, `继续翻译`, or `重试`.
- A completed translation is shown as the existing bilingual body and its
  primary banner action is `只看原文`.
- Clicking `只看原文` displays the original MIME message exactly as captured
  before translation and changes the action to `查看双语译文`.
- Clicking `查看双语译文` restores the current bilingual MIME snapshot and
  changes the action back to `只看原文`.
- The toggle is display-only. It does not mutate translations, invalidate the
  disk cache, call a provider, or create a translation task.
- A new full translation resets the view to bilingual once it finishes.

There is no translated-only mode. The two stable reading modes are original
and bilingual, which preserves the product's paragraph-by-paragraph reading
model.

## State Model

`TranslationStore` keeps the translation lifecycle and adds a display mode to
entries that have a bilingual snapshot:

```swift
enum DisplayMode {
    case bilingual
    case original
}
```

The initial mode is `bilingual`. It is meaningful only for completed
translations; translating, stopped, and failed states keep displaying their
latest bilingual snapshot (or the original when no snapshot exists) and retain
their existing task controls.

The store exposes one generation-guarded toggle operation. It succeeds only
when the message is complete and returns the requested render state. This
prevents a late action from restoring an obsolete snapshot over a newly started
translation.

## Mail Action Context

The context passed to `MEDecodedMessage` is encoded structured data rather
than just a message key. It contains:

- message key;
- monotonically increasing presentation token;
- advertised primary action.

Every call that renders a banner obtains a fresh token from the store and
embeds it in the context. `primaryActionClicked` validates the decoded context
against the currently presented token and action before changing state. A
re-delivery from Mail with an old token is ignored.

This is required because the primary action completion handler deliberately
remains open to avoid a macOS 26.5 Mail crash. In that lifecycle, state alone
cannot distinguish an old delivery from a later explicit click after the banner
has changed from Stop to Continue, or from bilingual to original mode.

## Refresh and Task Ordering

`MEExtensionManager.reloadVisibleMessages` is global to the extension process,
not to a message. The refresh coordinator is therefore a single extension-level
instance. It serializes reloads across all message keys, coalesces progress
updates, and retains the existing priority rules: terminal requests outrank
initial requests, which outrank progress requests.

Starting a translation reserves a task-registry handle before creating the
top-level task. The handler then records translating state, schedules the
initial reload, and attaches/starts the task. The task registry owns removal
using the reserved handle. A fast provider cannot complete before registration
or make the initial translating presentation disappear.

The original-view toggle requests a terminal-priority reload through that same
global coordinator. It performs no provider work.

## Rendering Rules

When decoding a complete message:

- `bilingual` returns the stored rewritten MIME, title `已翻译为...`, primary
  action `只看原文`;
- `original` returns the stashed original MIME, title `正在查看原文`, primary
  action `查看双语译文`.

If the original stash is unexpectedly unavailable, the handler returns the
bilingual snapshot and logs the failure rather than returning an invalid Mail
message. This should be unreachable for normal translated and cached messages,
because both paths stash the original before marking the state complete.

## Error Handling

- Invalid, malformed, stale, or mismatched action contexts are ignored.
- Toggle actions received while a translation is active are ignored; task
  controls are valid only for the banner generation that advertised them.
- A failed Mail reload is nonfatal. The display mode is already stored, and a
  later genuine state change can request another reload.
- A retranslation cancels or supersedes old display state through the existing
  generation rules and ends in bilingual mode after success.

## Testing

Unit tests cover:

- complete bilingual messages toggling to the exact original bytes and back;
- toggles preserving translations and avoiding a provider invocation;
- toggle rejection for non-complete messages;
- action-context encoding, decoding, and stale-token rejection;
- global refresh serialization when two message keys request reloads;
- task reservation before launch, including an immediately completing task;
- stale completions and stale action callbacks leaving the current state
  unchanged.

Integration verification runs `./test.sh`, `./build.sh`, and `./install.sh`.
Manual Mail verification confirms that the original and bilingual views switch
without Mail exiting, network activity, duplicated translation, or loss of the
translated body.

## Out Of Scope

- A translated-only reading mode.
- Persisting original-view selection across extension process restarts.
- Per-message reload calls that bypass the global reload coordinator.
