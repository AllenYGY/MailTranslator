# MailTranslator Xcode Cloud Setup

Repository preparation: 2026-10-19, branch `codex/app-store`. This is a setup
runbook; local verification below is distinct from Cloud execution.

## Live Onboarding Checkpoint

On October 19, the user completed initial Xcode onboarding. App Store Connect now
lists MailTranslator as a Cloud product (`3b442a97-3af7-41c3-810c-fa06646aee45`)
and completed checkout, signing, archive, and App Store delivery in builds 7 and 8
from `dace968`. The first run failed on stale project references; the regenerated
project and bundled test fixture fixed that prerequisite. Build 7 tests passed
9/10, with a ten-minute timeout in the simulated failed-purchase case.

The workflow is `MailTranslator App Store`, ID
`9CDE8C77-B1E3-4CF4-9813-E820414A7C3A`. Manual and push triggers select only
`codex/app-store`; clean builds, required macOS tests, and an App Store Connect
archive use the main MailTranslator scheme. There are no distribution post-actions.
Xcode is pinned to release 27.1 (27A9275), with stable macOS 27.0.1 (26A434).
Build 9 temporarily used macOS 27.2 beta 4 (26B5112a) for diagnosis: Apple's
[macOS release notes](https://developer.apple.com/go/?id=macos-27_2-rn)
report a fix for SKTestSession failed purchases showing dialogs despite dialog
suppression (184255116). The same case still waited in that environment, so the
release-note match does not establish the cause. The workflow was restored to
the stable image; no test was weakened or skipped. Do not switch to a beta Xcode
SDK for shipping. Current Cloud results are in `2026-10-19-apple-only-release.md`.

Repository ADMIN permission was verified. The old `ExtentionforMail` remote was
updated to the canonical `git@github.com:AllenYGY/MailTranslator.git` during
authorization troubleshooting. Successful product discovery does not by itself
prove checkout, signing, archive, tests, or App Store delivery.

## Repository Prerequisites

- Project: `MailTranslator.xcodeproj`, including `project.pbxproj`, is tracked.
- Shared schemes: `MailTranslator` and `StorePurchaseTests` are tracked.
- Project specification: `project.yml`; local generator: XcodeGen 2.46.0.
- App: `io.github.allenygy.mailtranslator`; extension:
  `io.github.allenygy.mailtranslator.extension`; team: `A5V794JT7G`.
- Both shipping targets use `APP_STORE`, automatic signing, and the App Store
  entitlement files under `Resources/`. Both require the App Group
  `group.io.github.allenygy.mailtranslator`.
- There are no tracked GitHub Actions workflows or existing Cloud scripts.

The tracked project has been regenerated with `xcodegen generate`. It no longer
references deleted provider sources, targets macOS 26, and includes
`StorePurchaseTests` in the main `MailTranslator` scheme. The test target copies
`Resources/MailTranslator.storekit` into its own bundle using the existing
`buildPhase: resources` pattern. Cloud uses this checked-in project, not
`project.yml`; regenerate locally and review the diff after specification changes.

No bootstrap script or new dependency is necessary: the project is not ignored,
and Cloud can discover it directly. Do not install Homebrew or regenerate the
project on every Cloud build to conceal a stale checked-in project. Homebrew and
XcodeGen exist on this development Mac; that does not prove XcodeGen exists in a
Cloud image. Apple documents Homebrew support for genuinely required tools in
the [workflow environment reference](https://developer.apple.com/documentation/xcode/xcode-cloud-workflow-reference).

## Initial UI Setup

These are operator steps, not actions performed by this task. Repository changes
must first be committed and pushed by the integration owner so Cloud can see them.

1. Open `MailTranslator.xcodeproj` in Xcode. Select the `MailTranslator` scheme,
   then **Product > Xcode Cloud > Create Workflow**. Select the MailTranslator
   product and team `A5V794JT7G`. Reuse the existing macOS MailTranslator app
   record; do not create another app or select the extension as the product.
2. Authorize the requested source-provider connection for this repository.
   Access to a local checkout alone does not grant Cloud access. Review any team
   or provider approval requests with the account owner.
3. Name the workflow `MailTranslator App Store Archive`. In **Environment**,
   select a supported stable Xcode with the macOS 26 SDK or newer and a compatible
   macOS 26-or-newer image. Local verification used Xcode 27.1 (27A9275); Cloud
   27.1 is now explicitly configured in the live workflow. Enable **Clean** for
   release archives. No custom environment variables or secrets are required.
4. Remove the default branch-change trigger for `main`. For the first smoke
   build, leave automatic start conditions unset and select `codex/app-store`
   when starting manually. After verification, optionally add **Branch Changes**
   matching only `codex/app-store`. Do not schedule the standalone `main` edition
   through this store workflow.
5. Under **Actions**, add **Archive**, platform **macOS**, scheme
   **MailTranslator**, **Deployment Preparation: TestFlight and App Store**.
   The scheme's Archive configuration is `Release`. Do not choose internal-only
   preparation for an archive intended for App Review.
6. Leave distribution post-actions disabled for the first smoke build. Do not
   add an automatic TestFlight group, App Review submission, or release action.
   Cloud signing must authorize both explicit App IDs and their shared App Group;
   no signing certificate, private key, or API key belongs in the repository.
7. Complete onboarding with a manual build of `codex/app-store`. If onboarding
   starts a build immediately, treat it as a non-distributing smoke build.
   Inspect the selected commit, archive logs, signing results, and downloadable
   archive before configuring upload/distribution.

Apple requires initial onboarding in Xcode; subsequent editing is available at
**App Store Connect > MailTranslator > Xcode Cloud > Manage Workflows**.
See [first workflow setup](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow)
and [action configuration](https://developer.apple.com/documentation/xcode/configuring-your-xcode-cloud-workflow-s-actions).

## Build Numbers And Delivery

Before any upload, use **App Store Connect > MailTranslator > Xcode Cloud >
Settings > Build Number > Edit Next Build Number**. Set an integer greater than
the highest previously uploaded macOS build, across all versions. Check the
current source `CFBundleVersion` and coordinate local uploads with this counter;
the source version alone does not establish the last uploaded number. This task
did not inspect current App Store Connect state.

Cloud supplies the distributed build number and increases it automatically; a
script that rewrites either source Info.plist is unnecessary. Setting the next
number requires Admin or App Manager access. Coordinate future local uploads
with the Cloud counter to avoid collisions. See Apple's
[build-number guidance](https://developer.apple.com/documentation/xcode/setting-the-next-build-number-for-xcode-cloud-builds).

After the smoke archive passes and the next number is safe, an authorized
operator can configure an App Store Connect upload post-action. Upload is not
App Review submission, approval, or release. Verify both embedded bundle versions,
App Group entitlements, architecture slices, and signing in the delivered archive.

## Cloud Tests

Do not claim that an archive action runs `./test.sh` or the hosted StoreKit tests.

`StorePurchaseTests` loads its fixture with `Bundle(for: PurchaseTests.self)` and
`url(forResource:withExtension:)`, not a source-checkout path or `Bundle.main`
(which is the host app). A missing fixture fails explicitly in test setup, and
teardown safely handles setup failure. Cloud runs `build-for-testing` and
`test-without-building` in separate environments; this bundled lookup supports
the source-less test-execution phase.

Add **Test > macOS > MailTranslator > Required To Pass > Use Scheme Settings**,
with an available macOS 26-or-newer destination. The main scheme now includes the
hosted StoreKit suite; `StorePurchaseTests` remains a dedicated alternative.
The trial tests assert real `StorePurchaseAccess.state()` grants trial access,
including before refund, and returns exactly `.unavailable` after the signed
trial revocation. Constructed policy records are retained only for policy-boundary
checks, not as the sole evidence of trial authorization.
Verify the hosted StoreKit results in Cloud. Local StoreKit simulation still
does not prove real sandbox purchase, restore, trial, or Mail extension behavior.
Apple's
[test-action documentation](https://developer.apple.com/documentation/xcode/configuring-your-xcode-cloud-workflow-s-actions)
describes the two execution phases.

## Custom Script Contract

No `ci_scripts/` files were added because no bootstrap is required. If a future
change needs hooks, Apple's recognized names are `ci_post_clone.sh`,
`ci_pre_xcodebuild.sh`, and `ci_post_xcodebuild.sh`, in `ci_scripts/` beside the
project. Use an explicit shebang, executable permission, and fail on errors.
Hooks run from `ci_scripts/`, not the repository root; post-clone repository work
should explicitly change to `"$CI_PRIMARY_REPOSITORY_PATH"`.

Use `CI_XCODEBUILD_ACTION` to distinguish archive, build, and test phases.
`CI_PROJECT_FILE_PATH` identifies the selected project; `CI_BUILD_NUMBER` is the
Cloud counter; `CI_XCODEBUILD_EXIT_CODE` is useful after xcodebuild. Do not dump
the environment or log credentials. Mark any future secret custom variables as
redacted. Do not assume files created by a hook persist into another action or
the source-less test phase. See [custom scripts](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
and the [environment variable reference](https://developer.apple.com/documentation/xcode/environment-variable-reference).

## Local Verification

- `git ls-files --stage MailTranslator.xcodeproj project.yml ci_scripts .github`
  confirmed tracked project/schemes and no existing CI scripts/workflows.
- `xcodegen generate` succeeded with XcodeGen 2.46.0. Repeating it preserved the
  hashes of the project file and both shared schemes.
- A focused hosted test failed with the expected missing-fixture `XCTUnwrap`
  assertion before the resource was added. Result:
  `/tmp/MailTranslator-CloudPrereqs-20261019-RED.xcresult`.
- Copied the regenerated project and current source to an isolated temporary
  checkout, ran `xcodebuild build-for-testing -scheme MailTranslator`, moved that
  checkout out of its original path, then ran `xcodebuild test-without-building
  -xctestrun <generated-run-file>` using its separate DerivedData products. Both
  commands used `-destination 'platform=macOS,arch=arm64'` and disabled parallel
  testing. All 10 hosted StoreKit tests passed, zero failures/skips, including
  the strengthened trial/refund assertions. Result:
  `/tmp/MailTranslator-CloudPrereqs-GREEN.QbMVcx/Tests-Assertions.xcresult`.
- The built fixture is inside
  `MailTranslator.app/Contents/PlugIns/StorePurchaseTests.xctest/Contents/Resources/`.
  The generated `.xctestrun` uses product-relative paths and no source fixture
  path. The build-time source checkout was unavailable during execution.
- `./test.sh` passed core tests, App Store edition isolation, and settings
  hit-testing. `plutil -lint` validated the project, `xmllint --noout` validated
  both shared schemes, and `git diff --check` found no whitespace errors.
- Release build-settings inspection confirmed macOS 26, `APP_STORE`, universal
  architectures, the expected team, app bundle ID, and App Store entitlements.
- Existing toolchain warnings remain: local out-of-date CoreSimulator, the
  extension's ignored linker `-e` option, and an Apple StoreKitTest header's
  deprecated payment-state type. They did not prevent these macOS tests.
- Temporary RED and GREEN test hosts/extensions were unregistered using
  `pluginkit -r` and `lsregister -u` against only their `/tmp/` paths. The final
  PluginKit inventory contained no registrations from these verification roots;
  existing application registrations were not removed or reconfigured.
- Only `project.pbxproj` and the main shared scheme require generated-project
  changes. No generated workspace or `xcuserdata` files belong in the change.
- No app was installed, no signing/provisioning updates were requested, and no
  Cloud build, upload, browser/ASC operation, or TestFlight installation change
  was performed. Local hosted tests used existing development signing. There
  are no new shell scripts requiring a syntax check.
