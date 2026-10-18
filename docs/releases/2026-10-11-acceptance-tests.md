# Release Acceptance Tests: 2026-10-11

## Scope And Outcome

Fresh checks ran approximately 11:31-11:32 HKT on 2026-10-11 in
`/Users/allenygy/Documents/ChatGPT/MailTranslator`.

- PASS: all four standalone executables in `./test.sh`; script exit code 0.
- PASS: installed TestFlight host and extension identify as version 1.0.0, build 4,
  have universal binaries, and pass the host's deep/strict signature verification.
- BLOCKED: `/tmp/MailTranslator-IAP-Build4.xcarchive` does not exist at inspection time.
  Its historical verification cannot be refreshed in this run.
- RELEASE ACCEPTANCE REMAINS OPEN: local tests and signature inspection do not
  close the real Mail/sandbox acceptance gate.

Hosted Xcode tests were deliberately not run, to avoid disrupting the concurrent
real UI capture. No installed app was launched, no app settings were saved, and
no source, Git state, accounts, purchase history, or extension registrations were
changed. The only authored repository file is this report. Existing changes were
preserved. The requested test script compiles in a temporary directory and removes
that staging directory on exit; its cache tests use disposable temporary data.

## Fresh Commands And Results

### Subsequent Leader UI Evidence

After the independent test pass, CUA captured real build 4 settings and the neutral
`sample-en.eml` Mail window. The leader switched an existing cached translation to
original-only and back to bilingual without reselecting the message, then returned
to original-only. The resulting banner and actual message text changed accordingly.
This closes the cached view-switch observation only, not fresh translation,
progressive rendering, stop/continue, or purchase-to-extension propagation.

Captures and reproducible bilingual artwork are retained in `docs/app-store`.
All eight output images passed 2560 x 1600/no-alpha checks. Visual inspection
confirmed the real content and no overlapping marketing text in the checked slides.
During further testing the Mac became locked; native automation reported that it
could not unlock it. A manual unlock is required before real Mail tests resume.

Environment commands:

```sh
date '+%Y-%m-%d %H:%M:%S %Z'
sw_vers
uname -m
xcodebuild -version
xcrun swiftc --version
```

Observed macOS 27.0.1 (26A434), arm64 host, Xcode 27.0 (27A266a), and Apple Swift
6.4 (swiftlang-6.4.0.34.1). The compiler target is arm64-apple-macosx27.0.0.

### Standalone Test Run

```sh
./test.sh
```

The script completed with exit code 0 and this output, in execution order:

```text
全部测试通过
Settings hit-test passed
全部测试通过
Settings hit-test passed
```

| Executable | Compilation mode | Fresh result |
| --- | --- | --- |
| core-tests | Swift 5 mode, standalone | PASS |
| settings-hit-test | Swift 5 mode, AppKit, standalone | PASS |
| store-core-tests | Swift 5 mode, APP_STORE, StoreKit | PASS |
| store-settings-hit-test | Swift 5 mode, APP_STORE + STOREKIT_UI_TEST | PASS |

No failing assertions or compiler warnings appeared in the captured test output.
These are four executable runs, not four XCTest cases; the harness does not print
an assertion count. No coverage instrumentation, lint, or separate full shipping
build was run. Runtime testing here is arm64 only, not x86_64 execution.

### Installed Build 4

```sh
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' -c 'Print :CFBundleShortVersionString' -c 'Print :CFBundleVersion' /Applications/MailTranslator.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' -c 'Print :CFBundleShortVersionString' -c 'Print :CFBundleVersion' /Applications/MailTranslator.app/Contents/PlugIns/MailTranslatorExtension.appex/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 /Applications/MailTranslator.app
codesign -dvvv /Applications/MailTranslator.app
codesign -d --entitlements :- /Applications/MailTranslator.app
codesign -dvvv --entitlements :- /Applications/MailTranslator.app/Contents/PlugIns/MailTranslatorExtension.appex
lipo -archs /Applications/MailTranslator.app/Contents/MacOS/MailTranslator
lipo -archs /Applications/MailTranslator.app/Contents/PlugIns/MailTranslatorExtension.appex/Contents/MacOS/MailTranslatorExtension
```

All commands above exited 0. Host bundle ID is
`io.github.allenygy.mailtranslator`; extension bundle ID is
`io.github.allenygy.mailtranslator.extension`. Both plists report `1.0.0` / `4`.
Both architecture commands return `x86_64 arm64`.

Deep/strict verification prepared and validated the embedded extension and reported
`valid on disk` and `satisfies its Designated Requirement` for the host.
Both signature displays report TestFlight Beta Distribution, team `A5V794JT7G`,
and the Apple Worldwide Developer Relations / Apple Root CA chain.
Both entitlements contain sandbox=true, outgoing network=true,
`group.io.github.allenygy.mailtranslator`, beta-reports-active=true, and their
respective explicit application identifiers. Entitlement display emitted only the
tool warning that the `:-` syntax is deprecated; signature verification itself
passed. This is static installed-bundle evidence, not runtime authorization,
Mail selection, purchase, or distribution-export validation.

### Requested Archive

```sh
ls -l docs/releases/2026-10-11-acceptance-tests.md /Applications/MailTranslator.app /tmp/MailTranslator-IAP-Build4.xcarchive
stat /tmp/MailTranslator-IAP-Build4.xcarchive
find /private/tmp -maxdepth 2 -name '*Build4*.xcarchive' -print
```

The initial `ls` exited 1: the requested report did not yet exist and the archive
was missing; the installed app existed. `stat` exited 1 with
`No such file or directory`. The bounded `/private/tmp` search exited 0 with no
matching archive. This does not prove absence elsewhere on disk.

No archive was rebuilt, replaced, or exported. Archive metadata, signatures,
architectures, profiles, and correspondence with the installed app are NOT freshly
verified. The prior successful archive in `app-store-preparation.md` remains
historical evidence only. Passing current-source tests also does not prove exact
source equivalence with the installed shipping binary.

## Coverage Inspection

Read-only inspection covered `test.sh`, `Tests/CoreTests.swift`,
`Tests/SettingsHitTest.swift`, `Tests/StorePurchaseTests/PurchaseTests.swift`, and
the relevant settings/purchase implementation. Coverage below is qualitative;
there is no measured line or branch coverage percentage.

- Core regressions: shared configuration path and missing-group rejection; endpoint
  normalization/HTTP restrictions; model request construction, decoding and errors;
  provider presets, profiles, migration and config coding; stale-request invalidation;
  stream markers, batch planning, HTML escaping, signer determinism, language checks,
  temporary cache round trip; translation action/store state, retained partial results,
  original-view toggles, pipeline cancellation, task reservations and stale handles,
  refresh ordering/coalescing with controlled executors.
- Purchase policy: verified original-download trial start, last second and exact
  604800-second expiry; missing, wrong-bundle, untrusted, future-dated and revoked
  app records; valid non-consumable unlock independent of app receipt; revoked,
  wrong-product, wrong-type and untrusted unlock rejection. These are synthetic
  records, not live StoreKit receipts or real refunds.
- APP_STORE-only core checks: request success and prompt timeout despite a slow
  underlying operation; rejection of Xcode credentials and acceptance of sandbox;
  existing-purchase restore skips synchronization; missing-purchase restore syncs
  once and rechecks; cancellation does not fabricate authorization; no-purchase
  result remains expired; a real 31-second injected login wait does not hit the
  old 30-second timeout. No real Apple authentication sheet is exercised.
- Settings checks: all three provider panels are selected in an in-process AppKit
  window; visible NSControls must have positive dimensions, fit the root bounds,
  and receive their center hit-test. Initial sizes are 660x550 standalone and
  660x680 Store; provider selection can resize the test window. The test does not
  save configuration or click purchase/restore. STOREKIT_UI_TEST suppresses initial
  StoreKit loading and transaction observation in PurchaseView.
- Settings limitations: not a screenshot/visual audit, actual system click test,
  text-clipping check, keyboard/accessibility audit, or full display/locale matrix.
  Labels and purchase busy/error transitions are not functionally verified.
- Integration limitations: `test.sh` compiles selected extension helpers, not the
  actual MailExtension, SecurityHandler, PopoverViewController or extension Settings
  integration. It does not exercise MailKit callbacks, real shared-file propagation,
  external provider requests, installed Apple language resources, or entitlement
  updates delivered to a live host and extension.
- Hosted suite inventory only: six XCTest methods cover product purchase/rediscovery,
  fixture refund, existing-purchase restore, restore without purchase, pending approval,
  and failed/cancelled purchase without a transaction. They use SKTestSession and a
  local .storekit configuration. None was run in this acceptance pass. The simulated
  cancellation test permits an error mapping instead of proving the precise real
  user-cancelled UI branch.

## Real Sandbox Evidence And Remaining High-Risk Gaps

The comparison baseline is the repository's `app-store-preparation.md`, especially
"Real Mail Sandbox Acceptance Gate", "Restore Authentication Regression And Build 4",
and "Build 4 Real Restore Acceptance". The following prior results are attributed
to that record, not independently replayed here:

| Scenario | Documented evidence | Remaining acceptance gap |
| --- | --- | --- |
| Containing-app identity | Build 3 real host and Mail extension verified Sandbox app transactions for the containing app | No fresh Build 4 runtime identity/extension-selection observation here |
| Purchase and propagation | Build 3 user observed localized CNY 6 purchase, host permanent unlock, and Mail translation without restart; logs showed unrevoked Sandbox unlock in both | No new Build 4 purchase-to-live-extension observation; current signature alone cannot establish this |
| Existing-purchase restore | Build 4 real restore clicks found verified permanent purchase without Apple login/forced sync | Previously verified, not repeated here; does not establish genuinely missing-transaction sync |
| Relaunch rediscovery | Build 3 fresh host rediscovered unlock; authorization survived failed/cancelled login and Mail translated another message | Reinstall restore with provider data preserved remains unverified |
| Active trial and expiry | Synthetic boundary tests pass; real sandbox expired denial is documented with Sandbox app identity | The baseline documents Apple's fixed historical sandbox original-purchase date, which cannot prove a fresh active trial. Fresh production download/trial and real expiry remain unverified |
| Refund/revocation | Synthetic policy tests pass; historical hosted local StoreKit fixture refund is documented | Real sandbox refund/revocation, propagation to both processes, and denied new translation after expiry remain unverified |
| Mail controls and settings | Build 3 basic translated-text display after unlock is documented; helper regressions pass now | Build 4 progressive text, stop, continue, original-only view, cached-result preservation, and actual provider configuration propagation need real Mail observations |
| Cancellation/pending/failure | Historical local hosted cases and current injected restore cancellation provide bounded evidence | Real purchase/authentication cancellation, pending and failed transactions must not grant access; precise UI/busy-state behavior remains unverified |

Highest-risk open work is real Build 4 Mail lifecycle/authorization behavior,
forced sync with genuinely missing transactions under real Apple authentication,
reinstall restoration without provider-data loss, and real revocation denial while
cached translations/original view/settings/stop remain usable. Production trial
behavior is a separate unverified scenario, not a sandbox-test success.

The missing archive also blocks a fresh artifact-level release audit. Real shipping
UI/review screenshots are outside this run and cannot be replaced by hit tests.
The broader metadata/privacy/release-preference gates in the preparation record
were not rechecked. No production trial or real refund is claimed tested, and this
report does not authorize App Review submission.

## Subsequent Leader Acceptance (2026-10-11)

The earlier matrix describes the automated audit's scope. The following checks
were subsequently performed against the actual installed TestFlight build 4:

- Fresh fictional 11-paragraph email translated with Apple Translation; bilingual
  text appeared automatically without reselection or restarting Mail.
- A fresh 40-paragraph message visibly progressed to 36/40 with mixed original
  and translated content and a Stop Translation control. That attempt finished
  before cancellation, so it alone is not a cancellation pass.
- `release-stop-resume-20261011.eml` contains 100 fictional paragraphs. Stop was
  clicked at 24/100; Mail reported stopped at 24/100, retained translated content,
  and displayed Continue Translation. Continue progressed to 48/100 and then
  completed all paragraphs, with the Original Only control restored. No Mail
  crash, reselection, or restart was observed in this sequence.
- Raw CUA evidence: `/tmp/MailTranslator-build4-fresh-translation-20261011.png`,
  `/tmp/MailTranslator-build4-stopped-20261011.png`, and
  `/tmp/MailTranslator-build4-resumed-complete-20261011.png`.
- Signed hosted StoreKit tests were rerun from an isolated source staging directory:
  six tests, zero failures, xcodebuild exit 0, TEST SUCCEEDED. Result bundle:
  `/tmp/MailTranslator-Acceptance-20261011.xcresult`; log:
  `/tmp/MailTranslator-Acceptance-20261011-StoreKit.log`.
- The temporary debug extension registration created by hosted tests was removed;
  the TestFlight application was not replaced by the test host.

Production active-trial/expiry, genuine missing-transaction authenticated sync,
reinstallation, real sandbox refund propagation, and live requests to every
user-selectable cloud provider remain unverified. Local StoreKit results do not
replace these real-environment checks.

## Store Metadata Progress

- Eight real-UI artwork images passed size/transparency and visual checks; four
  Chinese and four English screenshots were saved in the specified order.
- English app display name: `MailTranslator: Mail Translate`; category Productivity,
  age rating globally 4+ with Apple's regional exceptions, not Made for Kids.
- Owner confirmed necessary rights; the third-party content rights answer was saved.
- Owner-approved bilingual privacy policy published to public GitHub main in commit
  `62e9da9b55cbec6d5b737540a9ead43c01f01305`, without committing or replacing the
  dirty local worktree. Anonymous HTTP HEAD returned 200 for
  `https://github.com/AllenYGY/MailTranslator/blob/main/docs/privacy-policy.md`.
  Both localization policy URLs were saved in App Store Connect.
- Owner approved conservative disclosure of Emails or Text Messages for App
  Functionality, linked to identity, not for tracking. Answers were saved; the final
  privacy publication legal agreement was presented for action-time confirmation.
- Owner then accepted the action-time agreement. Apple showed Published by the
  account owner. Evidence: `/tmp/MailTranslator-privacy-published-20261011.png`.
- Download pricing was freshly checked as CNY 0.00 / USD 0.00. App availability,
  previously uninitialized, was configured for all 175 regions after release;
  Apple lists China mainland and other regions as Available on App Release.
  Evidence: `/tmp/MailTranslator-all-regions-20261011.png`.
- Permanent unlock price was rechecked at CNY 6.00 (US USD 0.99). Review screenshot
  persisted. The non-consumable was added to a draft and shows Ready for Review.
- Apple application Add for Review validation listed only missing Content Rights
  and App Privacy before those gates were addressed. No final review submission is
  claimed by this checkpoint. Manual release after approval remains selected.

## Final Review Submission

After the confirmed privacy publication and content-rights save, Apple's validation
accepted the application into the same draft as the non-consumable. The draft showed
Items Ready to Submit (2): macOS 1.0.0 (4) and MailTranslator Permanent Unlock.
Submit for Review then succeeded; Apple displayed 2 Items Submitted and the version
sidebar changed to Waiting for Review. Draft count became zero. Manual release
remained checked. Evidence: `/tmp/MailTranslator-submitted-20261011.png`.

Submission URL:
https://appstoreconnect.apple.com/apps/6821313136/distribution/reviewsubmissions/details/8eb866f2-22fa-4644-a548-1d049c169912

This is submission, not approval or a live release. Remaining real-environment test
limitations above remain open; they were not converted into passing test claims.
The final review details independently showed both items Waiting for Review,
submitted Oct 11, 2026 at 12:14 PM. Evidence:
`/tmp/MailTranslator-review-details-20261011.png`.
