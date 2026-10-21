# VZN Elite Venmo deployment — October 21, 2026

LIVE: https://vznelite.org
Cloudflare Worker: vzn-elite, account 5c052106020fdea2cdd13759f2b95ad3
Deployment version: 8ea2c6c9-5488-4ece-a218-be6b4cbace5a
Prior version for rollback: 33594f15-d730-4105-b550-58910ebbc20c

This source combines the current deployed website recovered from Cloudflare/public assets with the Venmo update. It preserves the newer manual contributions, administration routing, player signups, roster pictures, tournaments, coach contacts, calendars, email delivery, rate limiter, and live security headers. Secrets were preserved remotely and are NOT included.

Parents open Pay with Venmo from their Monthly Player Contribution section. They enter the amount shown for the issued month in Venmo, then report the payment date/reference. Reports remain pending. Administration > Finances contains Venmo reconciliation: manually record a receipt checked in Venmo or preview/import CSV; explicitly match the receipt and confirm the parent report. Matching checks the gross amount and date and cannot count the receipt a second time. Unmatched verified receipts count as income and remain listed for review. Gross receipts and fee expenses appear separately in finance totals, ledger, and export.

New monthly settings are $50 before support. Changing team contribution/support settings changes newly created records and current plan summaries. Previously created monthly records retain their original amount. The profile link does not prefill an amount in Venmo. Admins should create a record for the desired month using current settings. Historical records were not repriced or deleted.

CSV accepts statement preambles and extra columns with required ID, Datetime, Type, Status, Note, From, To, Amount (total), Amount (fee). It only accepts completed positive incoming payments to @VZNElite2030 / vznelite, excludes outgoing/transfers/refunds for separate review, and rejects unknown formats. Transaction IDs are strings and unique in the database. Matching duplicates are skipped; conflicting duplicates stop import. Missing fees require review rather than being silently treated as zero. A real export has not yet been supplied; test a preview before importing one. Older legacy-ledger entries with different references require manual duplicate review.

The link https://venmo.com/VZNElite2030 was verified in a browser and redirected to https://account.venmo.com/u/VZNElite2030, showing vznelite, @VZNElite2030, a business QR code, and 'Sign in to pay this business'. Its description refers to parents pooling basketball tournament funds. Business status is publicly confirmed. Venmo's published direct-payment rate is 1.9% + $0.10: $1.05 on $50, $48.95 net. Actual fees are entered/imported; other fees may apply. Fee source: https://venmo.com/business/profiles

New Stripe checkout and invoice API routes return 410 and card-session creation is removed. Legacy signed Stripe webhook handling is retained for reconciliation of prior events. Provider accounts, subscriptions and provider settings were not changed.

Supabase migrations have already been applied to cfxieoqafldmbrcibqwq. DO NOT rerun schema/bootstrap SQL on this project. The SQL included is a reviewable record. Parent reports, admin receipts and reviews use RLS and membership/ownership checks in private functions; direct browser writes are disabled. Existing auth and records were preserved.

Validation: 29 local tests pass; deployment build passes. Transactional Supabase tests validate ownership, unrelated-account isolation, forbidden parent imports/confirmation/direct writes, admin confirmation, duplicate replay, conflicting IDs and net ledger amounts. All fixtures rolled back. Published assets were checked by SHA-256 against local files, including retained administration/calendar/navigation modules. Homepage and account sign-in were opened in the browser. CSP headers are present. The published Stripe checkout endpoint returns 410. Authenticated parent/admin browser interaction was not tested with a real user login; database role tests and CSV unit tests passed.

Cloudflare authentication correction: the saved credential is an ACCOUNT token. Account verification and Worker settings access work. The earlier user-token verification failure did not require weakening security settings. Secrets, bindings, cron schedules, route and current observability settings were preserved.

GitHub was not pushed from this chat because repository operations were blocked earlier. This package is the current deployed source to synchronize to the repository. It replaces the earlier update-only archive, which was based on the older ZIP.


## Administrator parent fix
Published version 8ab70d53-2992-4916-a429-99d1e16627e9. My account now includes current plans for linked children plus personal Venmo contributions and reports for administrator guardians. The personal view filters responsible-parent dues and reports to the signed-in account and linked players. Administration retains team-management controls. Linked administrators may submit reports even without a separate parent role; server checks still require the matching payer and guardian link. All 30 tests and the transactional administrator-reporting assertion pass. Test fixtures rolled back.
