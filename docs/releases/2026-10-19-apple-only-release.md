# Apple-Only Release Acceptance

Date: 2026-10-19 (Asia/Hong_Kong). Release candidate: 1.0.0 (6).

## Distribution

- `codex/app-store`: Apple Translation only, macOS 26+, StoreKit trial/unlock.
- `codex/direct-distribution`: existing LLM, Volcengine and custom endpoints,
  standalone entitlements and build path. `main` also retains provider sources.
- Repository: `AllenYGY/MailTranslator`; corrected the old local remote name.
- Source change: `dace968`, pushed to `codex/app-store`.

## Evidence

| Check | Result |
| --- | --- |
| Core, edition isolation, settings hit tests | Passed via `./test.sh` |
| Hosted StoreKit integration | 10/10 passed locally on Xcode 27.1 |
| Cloud source-free test fixture | Passed with the original checkout unavailable |
| Standalone shell build for this branch | Passed; APP_STORE gates retained, no ungated CLI |
| Release archive | `/tmp/MailTranslator-Build6.xcarchive`, passed |
| Host and extension binaries | arm64 + x86_64; strict deep signature verification passed |
| Release provider isolation | No OpenAI/Volcengine/API-key provider symbols found |
| Build upload | Xcode export/upload succeeded; Apple processed build 6 as Ready to Submit |
| Real installation | `/Applications/MailTranslator.app` reports build 6; signature passes |
| Extension registration | Only the installed application extension is registered |
| Real Mail acceptance | User confirmed permanent unlock, new-message translation and original-only view after reopening Mail on build 6 |

The earlier user report was not initially accepted as build-6 evidence: local
inspection still found build 4. After the explicit TestFlight update, the installed
plist reported 6; the user then repeated the Mail checks successfully.

Local StoreKit evidence:
`/tmp/MailTranslator-CloudPrereqs-GREEN.QbMVcx/Tests-Assertions.xcresult`.
Core suite log: `/tmp/MailTranslator-Build6-CoreTests.log`.
Archive/upload logs: `/tmp/MailTranslator-Build6-{Archive,Upload}.log`.

## Store Configuration

- Free download, China mainland permanent unlock CNY 6; manual release.
- Trial: non-consumable, zero price, `io.github.allenygy.mailtranslator.trial7`,
  Apple ID `6824203213`. Explicit claim starts 604800 seconds from the verified
  original transaction; no automatic charge/renewal and no reinstall reset.
- Unlock: `io.github.allenygy.mailtranslator.unlock`, Apple ID `6821363540`.
- Both products have English and Simplified Chinese descriptions, review notes,
  and Apple-translation Mail review imagery. Removed residual provider fees/API
  configuration instructions from the unlock metadata.
- Product pages retain two actual Apple Translation Mail screenshots in each
  localization. Removed provider configuration and old purchase UI screenshots.
  Capture provenance remains in `docs/app-store/artwork-manifest.json`.
- App Privacy: Data Not Collected. Both privacy-policy localizations point to
  `https://github.com/AllenYGY/MailTranslator/blob/codex/app-store/docs/privacy-policy.md`.
  The direct edition's policy remains separately available on `main`.
- Rejected submission `8eb866f2-22fa-4644-a548-1d049c169912` was cancelled so the
  revised app and newly added trial could be placed in one macOS review package.
  All three items were submitted together at 15:58 Hong Kong time and show
  Waiting for Review. New submission: `e6d9f8d9-1a08-4212-8898-83766c3b0577`.
  This is submission, not approval or public release.

## Xcode Cloud

Product: `3b442a97-3af7-41c3-810c-fa06646aee45`.
Workflow: `9CDE8C77-B1E3-4CF4-9813-E820414A7C3A`, MailTranslator App Store.
Manual and push triggers are restricted to `codex/app-store`. Actions are required
macOS tests and an App Store Connect archive, both using the MailTranslator scheme.
No distribution post-action or automatic release is configured.

- First run used old commit `27596a8` and failed on deleted provider file references.
  Regenerating and committing the shared Xcode project resolved that failure.
- Cloud build 7 used `dace968` with Xcode 27. Its archive succeeded and was delivered
  to App Store Connect. Tests passed 9/10; the simulated failed-purchase test
  exceeded the ten-minute allowance. The test was not skipped or counted as passed.
- Cloud build 8 uses the identical source and explicitly pinned Xcode 27.1
  (`27A9275`), matching the local 10/10 run. Its archive succeeded; the test action
  failed again. Pinning Xcode alone did not resolve the failure.
- Cloud build 9 uses the identical source and release Xcode 27.1 on macOS 27.2
  beta 4 (`26B5112a`). Apple documents a fix for failed-purchase test dialogs
  ignoring dialog suppression (184255116) in that image. This is a diagnostic
  environment change, not a skipped test or a change to the submitted build.
  The test log confirms the execution VM also uses that image, but the same
  simulated-cancellation case still waits. The action ultimately failed again;
  9/10 tests passed; `testFailedPurchaseDoesNotCreatePurchase()` exceeded ten
  minutes on Virtual Machine (27.2). Its archive succeeded. The documented
  Apple issue is a hypothesis, not a
  confirmed cause. No additional speculative toolchain changes were made. See
  [Apple's release notes](https://developer.apple.com/go/?id=macos-27_2-rn).
- The saved workflow has been restored to stable macOS 27.0.1 (`26A434`) with
  release Xcode 27.1. Required testing remains enabled. Archives succeed, but
  the overall Cloud pipeline must not be described as fully passing.

## Remaining Limits

Real TestFlight claim of the new free trial using an account with no permanent
purchase, real reinstall/refund of that trial, and production purchase/expiry
remain unverified. Synthetic policy boundaries and signed local StoreKit tests
cover those entitlement decisions; they are not production transaction evidence.
Native window automation still fails with SCStreamError -3811, so build-6 Mail
interaction was performed and reported by the user, not by automated UI control.

Cloud failure is still open: isolate the simulated API error in a minimal Cloud
test target and retain the result bundle for an Apple Feedback report before
changing purchase behavior. Local success does not close this Cloud regression.

Local UI evidence directory: `/tmp/MailTranslator-ASC-20261019/`, including
`waiting-for-review-build6.png`, `cloud-stable-workflow.png`, and
`cloud-build9-test-failure.png`. The release submission remains build 6; later
Cloud archives did not replace it or publish the application.
