# App Store Artwork

The eight screenshots use actual TestFlight 1.0.0 (4) CUA captures. Mail content
comes from `Tests/fixtures/sample-en.eml`, with fictional example.com identities.
The LLM configuration capture has an empty API key and an unsaved provider selection;
it is not evidence of a successful live model request.

Regenerate from the repository root:

```sh
swift tools/render-app-store-artwork.swift
sips -g pixelWidth -g pixelHeight -g hasAlpha docs/app-store/screenshots/en/*.png docs/app-store/screenshots/zh-Hans/*.png
```

All exports are 2560 x 1600 RGB PNGs without alpha. Source captures are retained in
`captures`; crop rectangles and output order are recorded in `artwork-manifest.json`.
Cropping removes only the macOS capture/title toolbar and unused Mail window space.
No application controls, text, or translation states have been painted over.

Order in both localizations:

1. Bilingual reading in Mail
2. Original-only reading
3. Provider configuration
4. Apple Translation and permanent unlock

The English marketing copy surrounds the actual Chinese application interface.
These are not captures of an English-localized application. Apple Translation
requires macOS 26 or later and language resources. The CNY 6 claim applies only to
the China storefront. Third-party translation charges are separate.

## Upload State (2026-10-11)

A fresh App Store Connect page confirmed four Chinese screenshots in the exact
order above. A clean version tab subsequently saved the English description,
keywords, support URL, and four English screenshots in the same order. The native
page showed the saved checkmark and enabled Add for Review button. Evidence:
`/tmp/MailTranslator-English-assets-saved-20261011.png`.

The Chinese unlock artwork was accepted and persisted as the IAP review screenshot.
The non-consumable and application 1.0.0 (4) were submitted together; Apple confirmed
two submitted items and Waiting for Review. Manual release after approval remains
selected. Native capture recovered after reboot/unlock. The unsaved LLM preview
was returned to Apple Translation; no provider credential was overwritten.

Submission: https://appstoreconnect.apple.com/apps/6821313136/distribution/reviewsubmissions/details/8eb866f2-22fa-4644-a548-1d049c169912
Evidence: `/tmp/MailTranslator-submitted-20261011.png`.
