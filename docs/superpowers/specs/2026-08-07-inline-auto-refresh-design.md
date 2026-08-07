# Mail Inline Translation Auto-Refresh Design

## Goal

After the user clicks the Mail banner action, translate the current message, insert each translated segment directly below its source segment, and refresh the visible message without crashing Mail.

## Constraints

- MailKit exposes no API that mutates the current reader body in place.
- `MEExtensionManager.reloadVisibleMessages` is the supported refresh API.
- On this macOS 26 build, completing the primary action with either a view controller or `nil` tears down Mail's extension host and exits Mail.
- Translation remains asynchronous and cached. MIME rewriting continues to be the source of the bilingual body.

## Design

The primary action keeps its request open while translation runs. Because Mail may redeliver an uncompleted action, a per-message cooldown gate absorbs duplicate callbacks without suppressing later manual retranslation.

When translation finishes, `SecurityHandler` stores the rewritten MIME data and requests one guarded visible-message reload. Mail then invokes `decodedMessage`, which returns the cached rewritten data containing source text followed by translated text.

Refresh is attempted once per action. If Mail rejects the refresh or the extension session is interrupted, translation remains available in the progress controller and cache. The handler must not retry reload in a loop and must not terminate the extension process.

## Data Flow

1. User clicks Translate.
2. The handler decodes the message key and rejects duplicate callbacks inside the cooldown window.
3. The handler keeps the action request open, marks the store as translating, and starts the existing pipeline.
4. Batch results update the store and progress controller.
5. The completed translations are inserted below their source segments and saved to memory and disk cache.
6. The handler requests one visible-message reload.
7. Mail calls `decodedMessage`; the handler returns the bilingual MIME data.

## Error Handling

- Configuration and translation errors update the progress controller and do not request reload.
- Reload errors are logged as nonfatal; the translated content remains available from cache.
- Repeated clicks while translating reuse the active state instead of starting duplicate translation work.

## Verification

- Unit tests cover one-shot refresh decisions and bilingual MIME insertion.
- Build and signing checks must pass.
- In Mail, click Translate on an English message and verify that the bilingual body appears without selecting another message.
- Repeat the action and inspect system logs for Mail termination, ExtensionKit principal-object faults, and duplicate refresh calls.
