# Distribution Branches

| Branch | Engines | Distribution |
| --- | --- | --- |
| `codex/direct-distribution` | OpenAI-compatible LLMs, Volcengine, Apple Translation | Website and Homebrew; existing direct-release process |
| `codex/app-store` | Apple Translation only, macOS 26+ | Mac App Store, seven-day trial and permanent non-consumable unlock |

This is the direct-distribution branch. `./build.sh` produces the existing universal
standalone application; `./install.sh` installs that local artifact. The checked-in
Xcode project also uses direct-distribution entitlements and does not define
`APP_STORE` for the shipping application or extension. There is no StoreKit access
gate in this edition. API endpoint, per-provider credentials, model discovery, and
Volcengine signing remain supported. Apple Translation still requires macOS 26;
cloud providers remain available on macOS 14+.

Run `./test.sh` before releasing. Regenerate the checked-in project with
`xcodegen generate` after editing `project.yml`. Keep cloud-only policies on the
App Store branch. Selectively cherry-pick shared Mail rendering fixes; do not merge
the entire direct branch into the App Store branch or re-enable arbitrary APIs.

Both editions currently retain their existing bundle identifiers. Do not install
them side by side or expect their settings/purchases to migrate interchangeably.
Keep App Store/TestFlight installs separate from local direct-install testing.

The historical build-4 screenshots and release notes describe an earlier rejected
App Store configuration, not the shipping feature contract of the new store edition.
