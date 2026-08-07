# Progressive Translation and Cancellation Design

## Goal

Give immediate feedback after the user starts translating a message, progressively place completed translations below their source paragraphs, and let the user stop the active translation without crashing Mail or discarding completed work.

## Product Behavior

- The first Translate click immediately changes the Mail banner to `正在翻译... 0/N` with a `停止翻译` action.
- Each completed batch updates the bilingual message body. Every translation appears directly below its corresponding source paragraph.
- Progress reloads are coalesced with a minimum one-second interval. Initial and terminal state reloads bypass that interval but remain serialized.
- Clicking `停止翻译` cancels the active task and in-flight provider requests.
- Completed translations remain visible after cancellation. The banner becomes `翻译已停止 X/N` and its action becomes `继续翻译`.
- Continue translates only missing segments, preserving completed translations and their order.
- Successful completion saves the full translation cache and changes the action to `重新翻译`.

MailKit does not expose custom animation inside `MEDecodedMessageBanner`. Progress numbers and progressively appearing paragraphs provide the activity feedback without introducing a view controller, which is unsafe in the current Mail host lifecycle.

## Lifecycle Constraints

- `primaryActionClicked` must keep its completion handler open. Calling it with either `nil` or a view controller exits Mail on the tested macOS 26.5 build.
- `extensionViewController(messageContext:)` remains `nil`.
- Mail may redeliver an open primary-action callback without another user click. A callback cannot be interpreted as cancellation until Mail has rendered the translating banner at least once.
- All visible-message reload requests must be serialized and coalesced. Concurrent or unbounded reloads are not allowed.

## Architecture

### Translation Store

Extend the per-message state with enough information to distinguish presentation and cancellation:

- `idle`
- `translating(completedSegments, totalSegments, latestRewritten, cancellationPresented)`
- `stopped(completedSegments, totalSegments, latestRewritten)`
- `done(rewritten)`
- `failed(message, latestRewritten)`

The store continues to own the accumulated translations by segment index. Rendering a translating state marks `cancellationPresented` exactly once, making subsequent action delivery eligible to stop the task.

### Task Registry

A lock-protected registry owns one top-level Swift `Task` per message key. It supports register, cancel, and remove operations. Registration rejects duplicate work. Removal uses task identity or generation identity so an older task cannot remove a newer continuation task.

Cancelling the top-level task propagates through the pipeline into provider `URLSession` operations. The registry does not own UI state; `SecurityHandler` performs the state transition after cancellation is requested or observed.

### Translation Pipeline

The pipeline checks cancellation before enqueueing work, before starting each provider call, after each completed child task, and before invoking progress callbacks. Child tasks rethrow `CancellationError` instead of wrapping it as an ordinary batch failure.

Ordinary provider failures retain the current partial-success behavior. Cancellation stops enqueueing further batches, cancels the task group, and exits with `CancellationError` while preserving results already committed through batch callbacks.

Continuation builds inputs only for segment indexes absent from the store. Progress always means translated segment count divided by the message's total translatable segment count. It therefore remains stable when continuation work is repartitioned into different provider batches.

### Refresh Scheduler

Replace the one-shot success coordinator for this workflow with a per-task scheduler that:

- requests an initial reload after entering `translating`;
- accepts progress refresh requests after batch results;
- coalesces requests received during the throttle window;
- never runs two `reloadVisibleMessages` calls concurrently;
- performs a trailing reload when pending content exists;
- queues an immediate serialized reload for `done`, `stopped`, or `failed` state.

The scheduler does not retry failed Mail reloads in a loop. A failure is logged and later genuine state changes may request another reload.

## Action Semantics

`primaryActionClicked` resolves the action from the current message state:

1. `idle`: start a new translation.
2. `translating` with `cancellationPresented == false`: ignore the callback as Mail redelivery.
3. `translating` with `cancellationPresented == true`: cancel the registered task and transition to `stopped` while retaining partial data.
4. `stopped`: start a continuation using only missing segments.
5. `done`: clear prior translations and start a full retranslation.
6. `failed`: continue missing segments when partial data exists; otherwise retry the full message.

The existing time-based action gate remains useful for immediate duplicate delivery, but presentation state is the authoritative boundary between system redelivery and an explicit Stop click.

## Data Flow

1. The user clicks Translate.
2. The handler creates the batch plan, marks the message translating, registers its task, and requests the initial reload.
3. Mail calls `decodedMessage`; it returns the original or latest rewritten MIME with `正在翻译... 0/N` and `停止翻译`, then marks cancellation as presented.
4. Each successful batch is merged into the store and a bilingual MIME snapshot is built.
5. The scheduler periodically reloads the visible message, revealing completed translations beneath their source paragraphs.
6. On success, the complete snapshot is cached, state becomes `done`, the task is removed, and a final reload runs.
7. On Stop, the registry cancels the task, state becomes `stopped`, partial content is retained, and a final reload displays `继续翻译`.
8. On Continue, only untranslated segments are submitted and the same progressive flow resumes.

## Error Handling

- `CancellationError` maps only to `stopped`; it is never displayed as a provider failure.
- A race between completion and Stop is resolved atomically: a completed task remains `done`; otherwise cancellation wins and remains `stopped`.
- Provider failures retain successfully translated segments and show a retry/continue action.
- MIME reconstruction failure keeps the last valid rewritten data and reports a failure without deleting translations.
- Reload failure is nonfatal and logged. Translation and caching continue.
- Stale callbacks and task completions are rejected using message key plus task generation.

## Testing

Unit tests must cover:

- cancellation propagates through `TranslationPipeline` and prevents new batches from starting;
- cancellation is not converted into an ordinary provider failure;
- a repeated callback before translating UI presentation is ignored;
- a callback after presentation cancels exactly one task;
- partial translations survive cancellation;
- continuation submits only missing segments and produces correctly ordered bilingual MIME;
- refresh requests coalesce, never overlap, and issue a trailing refresh;
- completion/cancellation races cannot overwrite a terminal state with stale data.

Integration verification must run `./test.sh`, `./build.sh`, and `./install.sh`. Manual Mail verification must confirm immediate banner feedback, progressive paragraph insertion, working Stop and Continue actions, no duplicate translations, bounded reload logs, and an unchanged Mail process ID throughout the workflow.

## Out of Scope

- A custom progress popover or extension view controller.
- Token-level streaming inside a paragraph.
- Pausing and resuming the exact provider network stream.
- Persisting incomplete translations across extension process restarts.
