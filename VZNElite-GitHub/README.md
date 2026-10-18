# VZN Elite

Independent basketball team website prepared for vznelite.org. The website is deployed at https://vznelite.org/. HoodFlyLog and the original source project are unchanged.

Read [LAUNCH.md](LAUNCH.md) for confirmed destinations, setup, launch blockers, acceptance tests, and handoff.

## Development

Requires Node.js 22 or later. Run `npm ci`, then `npm run dev:worker` for the complete local Worker preview. `npm run dev` serves static pages only; payment APIs require the Worker preview. Never use live secret keys for development. The browser uses the existing VZN Supabase project, so do not submit live writes without intent; use separate test accounts or an isolated project for integration testing.

Run `npm test` for automated tests and `npm run build` for syntax and a Cloudflare deployment dry run. `npm run build` does not publish. `npm run deploy` refuses to run until the team account ID is set and rejects the original personal account.

## Included

- Branded public homepage without sample players/events or demo role switching.
- Existing verified accounts, parent registration requests, invited player accounts, and staff approval.
- Database-controlled admin/coach access, family links, private photos, shared calendars, availability, announcements, and planning ledger.
- Monthly invoices, Stripe-hosted payment authorization, and signed server-side receipt verification.
- Admin notification queue and optional scheduled email to all current verified administrators.
- Cloudflare security headers and pinned dependencies.

Payments remain disabled. Admin email notifications are enabled and their email-only database migration is applied. Billing database setup remains unapplied. Authentication redirects, SMTP, provider secrets, domain connection, and final policy approval remain launch requirements. Monthly invoices are paid individually; automatic subscriptions and automatic monthly issuance are not included.

Only `public/` is served as static assets. Server code is in `worker/`. Supabase SQL snapshots are reference/history; do not apply them as a batch. The obsolete bootstrap was moved out of the migrations directory to prevent accidental execution. No HoodFlyLog code retrieval was repeated; this package is based on the supplied existing VZN source.
