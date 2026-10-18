# App Store Purchase Implementation

Approved scope: free download, seven-day full trial, then a one-time non-consumable unlock priced at CNY 6. No subscription. Direct/Homebrew distribution remains unlocked.

- Product identifier: `io.github.allenygy.mailtranslator.unlock`.
- Trial begins at the original purchase date in a verified AppTransaction, not a mutable local preference. Exactly seven 24-hour days; reinstalling does not reset it.
- StoreKit 2 verifies the app identity and non-consumable transaction. Unknown, unverified, refunded and wrong-product records do not grant access. Production and sandbox environments are accepted; Xcode transactions require a testing build flag.
- The host offers localized StoreKit pricing, purchase, restore and retry with bounded waits. Pending and cancelled purchases have distinct feedback. Transaction updates refresh access.
- The Mail extension independently queries StoreKit before new translation/retry/continue. It must not trust an unsigned shared `isPro` flag. Existing translations, original/bilingual display and cancellation remain available.
- Translation already running may finish. Trial expiry gates the next new task, not reading an existing result.
- No account creation, backend, subscription or local credential sharing is added.
- App Store pricing is not changed until the new IAP-capable build and product can be submitted together. Build 1 has no purchase support and must not be released as a free download.

Implementation sequence: regression tests for access policy, shared StoreKit access service, host purchase UI, extension gate, local StoreKit fixture, standalone and App Store builds. Sandbox purchase/refund/restore and app-extension StoreKit runtime behavior require account-backed end-to-end verification; compilation does not prove those paths.

Known limits: device-clock rollback and sandbox reset behavior require explicit testing. StoreKit access failures deny new translation with retry guidance rather than pretending the user has an expired trial. Family Sharing is not enabled in the product unless separately chosen.
