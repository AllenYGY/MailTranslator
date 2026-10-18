# MailTranslator App Store Preparation

## Current Candidate: Apple-Only Edition (2026-10-19)

This section supersedes older provider and original-download trial descriptions below.

- `main` remains the direct/Homebrew edition with LLM, Volcengine, and custom APIs.
- `codex/app-store` removes third-party provider code and configuration. It requires
  macOS 26 and uses Apple Translation with installed source/target language resources.
- Build 4 was rejected under Guideline 3.1.1 (submission
  `8eb866f2-22fa-4644-a548-1d049c169912`). Build 5 (`27596a8`) was uploaded and
  processed; export compliance was completed on October 19. It is Ready to Submit
  and available to the existing MailTranslator Internal group.
- Build 6 corrects residual third-party-fee text and synchronizes the tracked Xcode
  project with the Apple-only sources for clean checkout/Cloud builds.
  Its archive at `/tmp/MailTranslator-Build6.xcarchive` succeeded, both executable
  slices are universal, and strict deep signature validation passed. Xcode reported
  upload success at 01:03 Hong Kong time on October 19. Apple processing is pending.
- Trial now starts after explicitly claiming a free non-consumable IAP, product
  `io.github.allenygy.mailtranslator.trial7` (Apple ID `6824203213`). Its signed
  original transaction date starts exactly 604800 seconds. Restore/reinstall does
  not reset it. No automatic billing or renewal. This replaces the previous
  receipt-download-date trial, whose Sandbox date is fixed in 2013.
- Trial availability: all countries/regions, China mainland base price CNY 0,
  equivalent zero prices in 175 storefronts. English and Simplified Chinese
  localizations were saved. The review image shows the actual Apple translation
  service in Mail, captured on build 4; it does not depict the newer trial-claim UI.
- Permanent unlock remains `io.github.allenygy.mailtranslator.unlock`, CNY 6 in
  China mainland. App download remains free; release remains manual.
- Chinese and English product descriptions and review instructions now describe
  Apple-only translation and the claim-based trial. Provider and old purchase UI
  screenshots were removed from both localizations. Genuine Apple bilingual and
  original-only Mail screenshots remain; their capture provenance is in
  `docs/app-store/artwork-manifest.json`.
- `./test.sh` passes core, edition isolation, and settings hit tests for build 6.
  All 10 hosted StoreKit tests also pass, including positive signed-trial access
  before revocation and exact denial afterward. The fixture was read from the test
  bundle with the original source checkout unavailable, matching Cloud test phases.
  Result: `/tmp/MailTranslator-CloudPrereqs-GREEN.QbMVcx/Tests-Assertions.xcresult`.
  `./build.sh` succeeds with Store gates and Store entitlements for both targets.
- The free trial item is complete and was added to the review draft (Ready for
  Review), not submitted independently. App Privacy now shows Data Not Collected,
  matching the Apple-only implementation and Apple's exclusion of on-device data
  from collection. The public policy URL still needs to point to this edition's
  policy after pushing it. Direct-distribution privacy remains on `main`.
- Xcode Cloud setup is documented in `docs/releases/xcode-cloud.md`. Initial
  onboarding was completed by the user in Xcode while native CUA capture remains
  blocked by `SCStreamError -3811`. The web team page now lists MailTranslator
  (`3b442a97-3af7-41c3-810c-fa06646aee45`), Cloud Build 1 in progress. This first
  run predates the pushed project repair; no Cloud build success is claimed yet.
- Cloud authorization troubleshooting confirmed the signed-in GitHub identity has
  ADMIN permission on `AllenYGY/MailTranslator`. Local `origin` still pointed at
  the renamed `AllenYGY/ExtentionforMail`; updated it to
  `git@github.com:AllenYGY/MailTranslator.git` and verified remote branch access.
  This removes a repository-identity mismatch; GitHub App access and a successful
  Cloud build still require verification.
- Real TestFlight trial claim/restore and build 6 Mail translation remain unverified.
  Existing build 3/4 permanent unlock/restore evidence below is historical and does
  not establish the new free trial path. No resubmission is recorded yet.

Initial preparation checked on 2026-10-10. Historical draft-state notes below are
retained as an audit trail. On 2026-10-11, version 1.0.0 (4) and the permanent unlock
were submitted together and reached Waiting for Review, with manual release.
The current acceptance report is `2026-10-11-acceptance-tests.md`; it distinguishes
verified checks from outstanding real-environment limitations.

## Verified State

- Platform: macOS.
- App bundle ID: `io.github.allenygy.mailtranslator`.
- Extension bundle ID: `io.github.allenygy.mailtranslator.extension`.
- Local version/build: `1.0.0` / `3`. Build 1 does not contain IAP and must not be submitted under the free-download model.
- App Store Connect account displayed: Junya YANG. Created MailTranslator macOS app record `6821313136`, primary language Simplified Chinese, SKU `mailtranslator-macos`.
- Store draft version: `1.0.0`, Prepare for Submission. Chinese description, keywords and support URL are saved. English product-page copy is prepared, but creation/saving of that version localization did not persist and remains incomplete. No version is live or submitted for review.
- Installed Xcode: 27.0 (27A266a).
- Available code-signing identities: Apple Development and Developer ID Application.
- No locally usable App Store distribution identity was found by `security find-identity -v -p codesigning`. Developer Portal does show Distribution Managed and Mac Installer Distribution Managed certificates; these are hosted signing identities, not evidence of a locally installed private key.
- `./test.sh` passed both core tests and settings hit-testing checks.
- Added `project.yml` and a generated `MailTranslator.xcodeproj` with app and Mail extension targets, automatic signing, and an `APP_STORE` compilation flag.
- App Store entitlements enable sandboxing, outgoing networking, and `group.io.github.allenygy.mailtranslator` for both targets. Standalone `build.sh` retains its existing entitlements.
- Shared configuration path resolution has regression coverage, including failure when a group container is unavailable.
- Unsigned universal archive succeeded at `/tmp/MailTranslator-AppStore.xcarchive`. This archive is not upload-ready.
- The current Mac was registered in the Developer Portal after user authorization. The initial "Your team has no devices" blocker is resolved.
- A signed development archive succeeded at `/tmp/MailTranslator-AppStore-Signed.xcarchive` using fresh derived data. Deep/strict signature verification passed. Its embedded development profile is still wildcard and lacks App Group authorization; this is not an upload-ready distribution archive.
- Registered explicit App IDs for `io.github.allenygy.mailtranslator` and `io.github.allenygy.mailtranslator.extension` in team `A5V794JT7G`. The portal identifier list verifies both registrations.
- After user authorization, registered `group.io.github.allenygy.mailtranslator` and associated it with the containing app and its extension only.
- Enabled `REGISTER_APP_GROUPS` and target App Groups capabilities in `project.yml`. Fresh universal signed archive succeeded at `/tmp/MailTranslator-AppStore-Registered.xcarchive`. Both embedded profiles now contain explicit application identifiers and the registered App Group. Deep/strict signature verification passed.
- App Store export succeeded at `/tmp/MailTranslator-AppStore-Export/MailTranslator.pkg`. Distribution summary verifies Cloud Managed Apple Distribution, Store provisioning profiles, sandbox/network/shared-group entitlements, version `1.0.0`, build `1`, arm64 and x86_64 for both binaries. Installer certificate chain verification passed.
- Xcode reported upload success on 2026-10-10 at 18:41 Hong Kong time. App Store Connect subsequently displayed `1.0.0 (1)` with Missing Compliance; after answering that the app implements neither proprietary nor additional standard encryption (system TLS/CryptoKit only), TestFlight displayed Ready to Submit. Selected and saved that exact build in the version draft.
- Signed sandbox app launched from the registered archive and displayed its configuration window. This is not an end-to-end Mail translation or shared-file propagation test.
- Native screenshot capture failed with ScreenCaptureKit error `-3811`; no shipping-UI screenshots were uploaded.
- User initially requested CNY 5, which the current Apple price selector does not offer. User then explicitly chose CNY 6. Saved a price schedule with China mainland (CNY) as the base; the current-price table verifies CNY 6. Other storefront prices were generated by Apple (for example USD 0.99).
- Saved user-provided review contact details with authorization. Those private details are intentionally omitted from this repository record.
- Prepared a bilingual privacy-policy draft in `privacy-policy-draft.md`; it is not published and no privacy questionnaire has been submitted. Release mode has not been confirmed; the existing automatic-release default remains unchanged.

## Required Work Before Review

1. Complete real sandbox purchase validation for draft build 3. Do not submit build 1 under the new free-download business model.
2. Validate settings propagation and full translation/cancel/original-view behavior in the signed sandboxed host and Mail extension. Existing standalone configuration remains separate; extension-side migration is implemented but not system-tested.
3. Capture real UI screenshots, publish a privacy-policy URL, and complete truthful privacy, age-rating and export-compliance responses.
4. Obtain the user's manual/automatic release preference. Confirm paid-app agreement status without accepting legal terms for the account holder. Pricing and review contact details are already saved.
5. Save remaining metadata and availability, submit for review, and verify the resulting status. Upload success is not review submission or approval.

Apple Translation currently requires macOS 26 and installed language support (`Sources/Providers/AppleTranslationEngine.swift`). The overall application targets macOS 14; store text must distinguish these requirements.

## Free Download And Permanent Unlock

The user superseded paid-download pricing with free download, a seven-day full trial,
and a CNY 6 non-consumable permanent unlock. There is no subscription.

- Product ID: `io.github.allenygy.mailtranslator.unlock`.
- Trial dates come from a verified `AppTransaction.originalPurchaseDate`, not a resettable local first-launch timestamp. The trial lasts exactly 604800 seconds from the first download, not seven days from first opening the app.
- The app displays StoreKit's localized product price, not a hard-coded currency amount.
- Both host and extension independently verify authorization. No shared preference grants paid access. Unknown/unverified authorization blocks new work; original-view switching, cancellation, configuration and existing results remain usable.
- The extension checks access before clearing results or contacting a translation provider. It preserves the Mail completion-handler crash workaround.
- The standalone/Homebrew build does not enable purchase gating.
- `./test.sh` verifies trial boundaries, revoked/untrusted/wrong-product credentials, StoreKit request timeouts, and both standalone and App Store settings hit-testing.
- Signed universal build 2 archive: `/tmp/MailTranslator-IAP-Build2-Final.xcarchive`; not uploaded or submitted.
- Local StoreKit tests use the dedicated `StorePurchaseTests` scheme and `Resources/MailTranslator.storekit`. Local test credentials are accepted only in the test target; the shipping app and extension reject the Xcode environment.
- Signed hosted StoreKit tests passed all four cases, zero failures/skips, in `/tmp/MailTranslator-StoreTests-7.xcresult`: purchase/restore, pending approval, failed purchase without a transaction, and signed refund revocation. The test scheme must launch the signed host with the StoreKit configuration; an unhosted runner returned `notEntitled`. Product loading retries account for initial StoreKit setup. The simulated cancellation may surface as `StoreKitError.unknown` on Xcode 27; the failed-purchase test proves no transaction is created, not the exact user-cancelled UI branch.

Release blockers: verify sandbox purchase, restore, refund and trial behavior with the real
Mail extension; verify the extension's StoreKit queries resolve the containing app
rather than the extension/Mail identity. If they do not, implement a verified
entitlement transport before release, never fall back to an unsigned shared flag.
The store draft download price is now free; the permanent unlock is separately CNY 6.
Local StoreKit tests are not a substitute for these sandbox checks. The Apple-signed
trial start is stable across reinstall, but expiry comparison uses device time;
this is not a claim of tamper-proof trusted-server-time enforcement.

## Build 3 UI And Store Preparation

- Settings now use native rounded fields and engine segments, stable provider-panel
  sizing, and a separate purchase/trial section. Authorization summary remains visible
  during loading or failures; purchase and restore actions show a spinner and prevent
  concurrent operations. Existing per-provider credentials and model-list behavior remain.
- `./test.sh` passed standalone and App Store core tests and hit-testing for all three
  engine panels. The settings check verifies visible controls have nonzero dimensions,
  fit inside the minimum-width window, and receive center clicks. It is not a visual audit.
- Signed hosted StoreKit tests passed 4/4, zero failures/skips, in
  `/tmp/MailTranslator-StoreTests-UI3.xcresult`.
- Signed universal archive: `/tmp/MailTranslator-IAP-Build3.xcarchive`. Deep/strict
  signature checks passed; both host and extension contain arm64 and x86_64.
- Distribution export: `/tmp/MailTranslator-IAP-Build3-Export/MailTranslator.pkg`.
  Export summary verifies build 3, Cloud Managed Apple Distribution, Store provisioning,
  and sandbox/network/shared-group entitlements for both targets. Installer signature
  verification passed.
- Xcode reported upload success at 22:37 Hong Kong time. App Store Connect displayed
  build 3; after the same system-crypto-only export-compliance answer as build 1,
  its status became Ready to Submit. This is not TestFlight installation or App Review.
- Replaced the version draft's build 1 association with `1.0.0 (3)` and saved.
  The build table still shows build 3 after reopening the draft. No review submission
  or release action was performed.
- Created non-consumable `MailTranslator Permanent Unlock`, Apple ID `6821363540`,
  product ID `io.github.allenygy.mailtranslator.unlock`. China mainland base price
  CNY 6 and availability in all 175 regions were verified. Chinese and English display
  names/descriptions and review notes persist after reopening. Status: Prepare for
  Submission. A real purchase-screen review screenshot is still missing.
- Changed the app download schedule to CNY 0 with immediate effect; the current-price
  table verifies free comparable prices. The app has never been released, so there are
  no existing paid-download customers to migrate in this initial release.
- Updated the saved Chinese product-page copy to explain free download, seven days
  from the original download, one-time permanent unlock, no subscription, and separate
  provider fees. English copy is prepared below, but App Store Connect did not persist
  its new version localization after saving and returning; no actionable validation
  error was shown. Do not treat an edited field as proof of server-side persistence.
- Evidence images are in `/tmp/MailTranslator-ASC-20261010/`: `free-download.png`,
  `iap-price.png`, `build3-ready.png`, and `draft-build3.png`. They show administration
  state, not shipping UI.
- The user completed Sandbox Apple Account creation. The user-requested Gmail alias
  and China mainland storefront are visible after reloading the tester list. No password
  was read, generated, or stored by the agent.
- Native screenshot capture still fails with ScreenCaptureKit `-3811`. Offscreen test
  renderings were incomplete and were not uploaded as review screenshots. Real UI
  appearance and actual Mail sandbox behavior remain unverified.
- Added privacy-safe `PurchaseAccess` logging for host/extension bundle identity,
  verified StoreKit environment, revocation state, and error domain/code only. It does
  not log credentials, Apple Account details, signed transactions, or email content.

## Real Sandbox Test Preparation

- Rechecked the newly created Sandbox Apple Account on 2026-10-10; account creation
  is confirmed, but this is not evidence of a completed purchase or Mail authorization.
- The Paid Apps Agreement is Active. Agreement contents, financial/account details,
  and personal address information are intentionally not copied into this record.
- Created `MailTranslator Internal` as a manual-distribution internal TestFlight group;
  automatic distribution is off. Added only `1.0.0 (3)`, whose status is Ready to Test.
- Invited only the existing account holder as an internal tester. The group shows
  1 Tester and 1 Build, and the tester status is Invited (not Accepted or Installed).
  Proof: `/tmp/MailTranslator-ASC-20261010/internal-invited.png`.
- The existing `/Applications/MailTranslator.app` still reports build 1 and empty
  entitlements, so it is not the new sandboxed Store build. It was not replaced by
  the agent. The user subsequently installed the invited TestFlight build alongside
  it as `/Applications/MailTranslator 2.app`; use that copy for purchase testing.
- Native control of `/Applications/TestFlight.app` failed again with ScreenCaptureKit
  `-3811`. The agent cannot currently operate the TestFlight installation, Apple login,
  purchase sheet, or Mail UI. The release acceptance gate below is still open.
- Apple documents that TestFlight apps always use sandbox purchases. Downloading a
  beta uses a production Apple Account, not the Sandbox Apple Account. On macOS, the
  Sandbox Apple Account sign-in is in App Store settings after an in-app purchase
  attempt. Do not sign out of or replace the user's everyday system account just to
  perform this test. Check the actual account/environment shown before purchasing.
- Changes to product metadata can take up to one hour to reach Apple's sandbox.
  An empty product list immediately after setup is not sufficient proof of a code bug.
- Official reference: [Testing Apple In-App Purchases with sandbox](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox).

### Installed TestFlight Build And Extension Selection

- After the user's installation, verified `/Applications/MailTranslator 2.app` as
  `1.0.0 (3)`, signed by TestFlight Beta Distribution, team `A5V794JT7G`. The installed
  host has sandbox/network/App Group/beta-reporting entitlements and a Store receipt.
  Deep/strict signature verification passes. A receipt file alone does not prove a
  verified StoreKit sandbox transaction or permanent unlock.
- The running Mail extension process was still executing the old
  `/Applications/MailTranslator.app/Contents/PlugIns/MailTranslatorExtension.appex/Contents/MacOS/MailTranslatorExtension`.
  PluginKit also listed three temporary development/archive copies and the new
  TestFlight copy. Installing build 3 did not replace Mail's already-running extension.
- Removed only those three temporary copies and the old installed copy from PluginKit's
  registration using `pluginkit -r`, then registered the TestFlight extension with
  `pluginkit -a`. No application or configuration files were deleted. The fresh
  `pluginkit -m -A -D -vv -i io.github.allenygy.mailtranslator.extension` result lists
  exactly one extension, inside `MailTranslator 2.app`. These registrations are
  reversible with `pluginkit -a` for a preserved copy; launching old copies may register
  them again. Do not launch development archives during the real sandbox test.
- Mail still needs a full quit/relaunch to release the already-running old extension.
  Native control of the newly installed app still fails with ScreenCaptureKit `-3811`;
  the optional native launch-only API is unavailable. No alternate UI automation or
  security-permission bypass was used.
- The initial privacy-safe `PurchaseAccess` log query returned no events. Requested
  the user to open the new app via TestFlight, quit/relaunch Mail, and translate neutral
  test content before checking authorization evidence. Sandbox host/extension queries,
  purchase, restore and actual translation remain unverified at this checkpoint.
- Subsequent real host logs at 23:02 Hong Kong time confirm a verified app transaction
  for `io.github.allenygy.mailtranslator` in the Sandbox environment, from the installed
  TestFlight host process. This proves host receipt identity/environment only, not
  trial display, permanent purchase, or extension access. The installed extension's
  signature includes sandbox/network/App Group/beta-reporting entitlements. No extension
  authorization event has yet been observed; Mail still had its original process ID
  before the requested full restart.

### Real Extension Authorization And Sandbox Trial Limitation

- After the user's Mail restart, process `23749` runs the extension executable inside
  `/Applications/MailTranslator 2.app`; Mail is process `23742`. At 23:07 Hong Kong
  time, three authorization queries from that extension report the verified containing
  app bundle `io.github.allenygy.mailtranslator` and environment `Sandbox`. This
  verifies the real extension's app-transaction identity, not an IAP entitlement.
- The user reports that translating displays the seven-day trial-ended message.
  Apple documents that `AppTransaction.originalPurchaseDate` is always
  `2013-08-01 00:00 PDT` (`1375340400000` Unix milliseconds) in sandbox. The current
  policy therefore evaluates this verified sandbox app transaction as expired. This
  is not evidence that the new installation is seven days old or that Mail is still
  using the old extension. The date itself was not logged from the user's receipt.
- Official reference: [AppTransaction.originalPurchaseDate](https://developer.apple.com/documentation/storekit/apptransaction/originalpurchasedate).
- Do not substitute receipt refresh time or a resettable local first-launch date for
  the production trial start, and do not grant unlimited sandbox access. Production
  trial policy remains unchanged. An active original-download-based trial cannot be
  demonstrated using this TestFlight sandbox date; local boundary tests and an eventual
  real production download check are distinct evidence and must be reported separately.
- The user subsequently reports the product sheet showed `MailTranslator Permanent
  Unlock` at CNY 6 and that they confirmed purchase. At 23:12:30 Hong Kong time, the
  same TestFlight host process `23325` logs `verified unlock environment=Sandbox,
  revoked=false`. The app's verified matching non-consumable transaction maps to
  permanent unlock; this confirms a real sandbox purchase, not a production charge.
- At 23:15:52 Hong Kong time, the same Mail extension process `23749` logs
  `verified unlock environment=Sandbox, revoked=false`. Host, Mail, and extension
  process IDs are unchanged from before purchase. The user confirms the host shows
  permanently unlocked and Mail successfully translates and displays translated text
  without restart. Real sandbox purchase-to-extension authorization and basic rendering
  are verified using both process logs and user observation, not a local StoreKit fixture.
- Restore after relaunch/reinstall, sandbox revocation, and post-unlock progressive
  rendering/stop/continue/original-only interactions remain separate unverified checks.
  Next handoff: relaunch the TestFlight host, use Restore Purchase under the same test
  account, and check that host and Mail translation retain access without repurchasing.

### Real Mail Sandbox Acceptance Gate

Use the intended TestFlight build or a correctly sandbox-enabled development
installation, with no local `.storekit` configuration. Do not replace the user's
standalone installation or clear production purchase history merely to run this test.

1. Confirm the installed version/build and enable that copy's extension in Mail.
2. Check that host and extension authorization logs report a verified `.sandbox`
   environment and the containing app bundle ID. A different identity or unknown
   authorization is a release blocker, not a reason to bypass verification.
3. Verify active-trial boundaries using controlled local StoreKit/policy tests; the
   fixed historical sandbox purchase date cannot prove a real active trial. Track a
   fresh production-download trial check separately. Exercise real Mail progressive
   text, stop, continue, original-only view, and provider configuration after sandbox unlock.
4. The user's expired-trial denial and the extension's verified Sandbox app transaction
   are observed. Apple's fixed sandbox date explains this result; it does not prove
   seven days elapsed since installation or validate production trial behavior.
5. Complete a visibly sandbox purchase, confirm the localized CNY 6 product, and verify
   the host and Mail extension both become unlocked without restarting or changing mail.
6. Verify restore after relaunch/reinstall under the same sandbox account, preserving
   provider data. Cancellation/pending/failed purchases must not grant access.
7. Exercise sandbox refund/revocation where supported; verify new translation is denied
   after expiry while cached translations, original view, settings and stop still work.

Capture actual Mail observations and privacy-safe logs for these checks. The 4 local
StoreKit tests do not fulfill this gate. Do not submit until this gate and review
screenshots are complete.

### Restore Authentication Regression And Build 4

- The user's restore screenshot shows Apple's sign-in sheet rejecting credentials
  while the app still reports permanently unlocked and a request-timeout message.
  No credentials or private account identifier were recorded. A fresh host process
  `24904` at 23:18:16 Hong Kong time already verifies an unrevoked Sandbox unlock,
  establishing entitlement rediscovery after relaunch, not successful forced sync.
- After cancelling the failed Apple login, the user confirms the app remains
  permanently unlocked and Mail translates another previously untranslated message.
  At 23:40:50 Hong Kong time, the unchanged extension process `23749` again logs
  `verified unlock environment=Sandbox, revoked=false`. The installed TestFlight
  app's plist still reports build 3. This verifies retained authorization after
  failed/cancelled authentication, not build 4's corrected restore flow or successful sync.
- The old restore implementation always called `AppStore.sync()` through the
  30-second `StoreRequest` wrapper. Apple's authentication sheet can outlive that
  timeout, while the UI re-enables restore and reports an error. Apple's documentation
  recommends normally using automatically available transactions and forcing sync
  only when transaction information is missing.
- Added a restore path that checks verified permanent purchase first. If present,
  restore succeeds without unnecessary authentication or another product request.
  Otherwise, explicit restore awaits Apple's sync until authentication completes,
  fails, or is cancelled; it does not apply the background-request timeout. Busy UI
  remains active during authentication, and cancellation does not change authorization.
- Red/green regression evidence: the extracted old behavior failed five assertions,
  including redundant authentication and a simulated login exceeding 30 seconds.
  The corrected `./test.sh` passes standalone and Store core tests and both settings
  hit tests. Six signed hosted local StoreKit tests pass with zero failures, including
  restore of an existing purchase and restore without any purchase. Result bundle:
  `/tmp/MailTranslator-StoreTests-Restore4.xcresult`.
- Build 4's signed universal archive succeeded at
  `/tmp/MailTranslator-IAP-Build4.xcarchive`; host and extension both identify as
  `1.0.0 (4)`, contain `arm64` and `x86_64`, pass strict signature verification, and
  have sandbox/network/App Group entitlements. Xcode reports upload success at
  23:28 Hong Kong time. Apple completed processing; after the unchanged system-only
  encryption declaration was saved, build `1.0.0 (4)` became Ready to Submit. Added it
  to the existing `MailTranslator Internal` group and verified that association in the
  build row. No new testers were added. Evidence:
  `/tmp/MailTranslator-ASC-20261010/build4-internal-ready.png`.
  Build 4 installation and existing-purchase restore acceptance are verified below.
  No App Review was submitted.
- Removed the temporary StoreKit test host from PluginKit registration after testing;
  the installed TestFlight build 3 remains the sole registered Mail extension. No
  installed apps or provider settings were replaced or deleted.
- References: [AppStore.sync()](https://developer.apple.com/documentation/storekit/appstore/sync())
  and [sandbox testing](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox).
  TestFlight sandbox purchases can be attributed to the normal Apple Account;
  the transaction environment alone does not identify the purchasing account. Do not
  change the user's system account or assume the separately created tester owns this purchase.

### Build 4 Real Restore Acceptance

- The user confirms that Restore Purchase now succeeds without an Apple login sheet.
  The installed/running app is now `/Applications/MailTranslator.app`, not the former
  `MailTranslator 2.app`; its plist reports build 4, its signature is TestFlight Beta
  Distribution for team `A5V794JT7G`, and deep/strict signature verification passes.
- Host process `27688` verifies an unrevoked Sandbox unlock at 23:42:41 Hong Kong
  time. Restore clicks at 23:42:59 and 23:43:00 each log `restore authorization check`,
  a verified unrevoked Sandbox unlock, and `restore found verified permanent purchase`.
  Neither click enters the forced-synchronization path. This verifies build 4's existing
  purchase rediscovery and no-extra-authentication flow with a real TestFlight purchase.
- PluginKit lists only build 4's extension inside the new installed path. The Mail
  extension is not currently running at this checkpoint, so these host observations
  do not establish a new build 4 Mail-rendering test. The purchase-to-Mail translation
  path was already tested on build 3; its translation/authorization policy is unchanged.
- Replaced the App Store version draft's build 3 association with `1.0.0 (4)`, saved,
  and reloaded to confirm persistence. The version remains Prepare for Submission;
  no Add for Review or Submit for Review action was performed. Evidence:
  `/tmp/MailTranslator-ASC-20261010/draft-build4.png`. Existing metadata/release settings
  were left unchanged; the live draft currently has automatic release selected, which
  still needs the user's release preference resolved before an eventual submission.
- Forced synchronization for genuinely missing transactions under real Apple login,
  reinstall restoration, sandbox revocation, and production trial behavior remain
  distinct unverified scenarios. No purchase history or system Apple Account was changed
  by the agent to simulate them.

## Proposed Store Text

Draft copy only. This does not establish pricing or privacy questionnaire answers.

### Simplified Chinese

Name: MailTranslator

Subtitle: Mail 邮件双语翻译

Description:

在 macOS Mail 中阅读外语邮件时，将译文显示在原文下方。MailTranslator 提供渐进式双语阅读、停止翻译、续译和只看原文等操作。

支持 OpenAI 兼容 LLM、火山引擎机器翻译，以及 macOS 26 或更高版本上的 Apple 系统翻译。LLM 服务可分别保存 API 地址、API Key 和模型配置，并可从兼容服务获取模型列表。

云端翻译需要使用者自行配置相应服务；服务可能收取费用。邮件正文仅在请求翻译时发送至选择的服务。Apple 翻译需要设备支持的语言与已安装的语言资源。

安装后，在 Mail 的设置中启用邮件翻译扩展，再打开 MailTranslator 配置翻译服务。

免费下载，提供 7 天完整试用。试用期从首次 App Store 下载时间开始计算；试用结束后，可通过一次性应用内购买永久解锁翻译功能，无订阅。永久解锁不包含第三方翻译服务费用。已生成的译文和只看原文功能不受试用到期影响。

Keywords: 邮件,翻译,双语,Mail,LLM,阅读

### English

Name: MailTranslator

Subtitle: Bilingual translation for Mail

Description:

Read translated messages alongside their original text in macOS Mail. MailTranslator provides progressive bilingual reading, controls to stop and continue translation, and an original-only view.

Choose an OpenAI-compatible LLM, Volcengine Machine Translation, or Apple Translation on macOS 26 or later. Each LLM provider preset stores its own API URL, key, and model configuration. Compatible providers can supply a model catalog directly.

Cloud translation requires your own provider configuration and may incur service charges. Message content is sent to the selected service only when you request translation. Apple Translation requires supported languages and installed language resources.

After installation, enable the extension in Mail settings and open MailTranslator to configure a provider.

Free download includes a 7-day full trial starting from your original App Store download date. After the trial, a one-time in-app purchase permanently unlocks translation, with no subscription. Third-party provider fees are not included. Previously translated messages and the original-only view remain accessible after trial expiry.

Keywords: mail,translation,bilingual,email,LLM,reader

## Official References

- [App Review Guidelines, 2.4.5 and 2.5](https://developer.apple.com/app-store/review/guidelines/)
- [Distribution certificate types](https://developer.apple.com/help/account/certificates/certificates-overview)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
