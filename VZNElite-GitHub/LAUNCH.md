# Production domain active

https://vznelite.org/ is attached to the verified VZN Elite account/Worker and was checked over HTTPS: HTTP 200, security headers present, homepage and sign-in screen render. Cloudflare version `a0672c7d-56bf-4813-940d-78217fca1ebc`. The workers.dev and preview routes were disabled by this deployment; local configuration now records those settings explicitly. Admin email links use the .org domain. Stripe stays disabled.

The owner reported saving the production Site URL and root/recovery allowlist in Supabase. The invite-player function was updated to version 2 to allow the .org origin and send invitation links to https://vznelite.org/. Verified production-origin unauthenticated requests return 401; unrelated origins return 403. End-to-end confirmation, recovery, and player-invitation email clicks still require owner acceptance; no real auth flows or passwords were submitted by the agent.

Domain attachment changed only the website binding through Cloudflare Workers custom domains; no email record edits were issued. DNS-record listing was not permitted by the saved token, so no full before/after email DNS comparison was available. Earlier Resend delivery was confirmed by the owner.

---

# Email deployment update

Email-only migration `admin_account_notifications` was applied to the existing VZN Elite project. RLS is enabled, and queue-claim execution is denied to anonymous and ordinary authenticated users. The Worker now has encrypted Resend/server credentials, `NOTIFICATIONS_ENABLED=true`, sender `VZN Elite <notifications@vznelite.org>`, and notification links pointing to the current workers.dev website. Version: `f9f5e85d-c850-4c16-9723-d743a74433fb`. Payments remain disabled; billing SQL remains unapplied.

The saved VZN server key was checked against project/role claims and a successful database request. Resend SMTP authentication passed without sending a message. All 24 tests and the Cloudflare build passed. A real inbox delivery test has not been performed. Supabase SMTP configuration was reported saved by the owner; final-domain redirects are still outstanding. No DNS changes were made during this step.

Do not apply the original combined SQL or repeat admin_notifications_setup.sql. Only billing_setup.sql remains pending for Stripe approval. Update NOTIFICATION_SITE_ORIGIN to the final .org address when it is connected.

---

# Deployment update

The website was deployed with user approval to Cloudflare account `5c052106020fdea2cdd13759f2b95ad3` as `vzn-elite`.

- Test URL: https://vzn-elite.vzn-elite.workers.dev
- Version: `4f020d92-c673-425a-a630-9c2283a28fcd`
- Payments and notifications remain disabled; no service/Stripe/email secrets were installed.
- Cloudflare registered the account workers.dev subdomain during deployment. No vznelite.org zone/DNS records were changed.
- Public URL verification is pending propagation. Final-domain setup, database setup, sender setup, and provider acceptance remain outstanding.

---

# VZN Elite launch and transfer

## Prepared destination

- Cloudflare account: the account shown as Vznelitebasketball@gmail.com. Account ID `5c052106020fdea2cdd13759f2b95ad3` was verified through the saved scoped token and is set in `wrangler.jsonc`.
- Worker: `vzn-elite`, recreated in that team account.
- Intended domain: `vznelite.org`. No route or DNS record has been changed.
- Supabase: existing `vznelitebasketball Project`, reference `cfxieoqafldmbrcibqwq`. Confirm team ownership before applying the pending setup.
- Payments: the team's existing Stripe account; account ID, payout ownership, test/live mode, and refund terms still need confirmation.
- New-account notices: every current verified administrator, determined from protected database roles rather than a hardcoded mailing list.
- Email integration prepared: Resend, with a verified team-owned sender still to be chosen. Supabase Auth also needs a production SMTP sender for confirmations, recovery, and player invitations.

## What is ready locally

The public site no longer offers a role-switching demo or publishes sample rosters or events. Registration/sign-in lead to the existing authenticated team workspace. Approved family links govern player edits, private photos, schedules, availability, and consent history. Admin roles remain database-controlled; signup never grants staff privileges. Parents request family access; invited players verify their own email before accepting player-only access.

The payment implementation issues one immutable invoice per player per month, with an assigned billing parent and the current support amount. Administrators issue months explicitly. Each month requires a separate Stripe Checkout authorization; this release does not create automatic subscriptions, issue scheduled invoices, or charge stored cards. Planning installment counts do not issue or limit invoices automatically. Families see only their own payable invoices. Changing dues, guardians, or roster status does not rewrite historical invoices. Zero dues are marked covered, not paid. Positive card invoices must be at least $0.50. Card checkout uses USD. A signed Stripe webhook verifies amount, currency, and session before recording payment; returns to the site never mark an invoice paid.

Refunds, disputes, off-site payments, voiding, and payer reassignment are not automated. Resolve these with the organizer and reconcile Stripe records before launch. Stripe payments do not automatically add entries to the separately maintained planning ledger. Existing subscriptions in the partially configured Stripe account are not imported or changed. Confirm those separately to avoid duplicate billing.

Notifications queue future verified accounts in the database. All administrators can see the queue. A scheduled Worker attempts delivery every five minutes, with a ten-minute lease and at most ten attempts. Each verified current administrator receives a separate message. Provider idempotency keys reduce duplicate delivery on retries. Failed deliveries remain visible; administrators must investigate exhausted items. Provider acceptance does not prove inbox delivery. No historical notification backfill is enabled.

## Confirm before live changes

1. Team Cloudflare account ID and domain ownership.
2. Existing Supabase project and organization are team-controlled. Do not create a replacement or migrate data from HoodFlyLog.
3. Stripe account ID and test/live mode, team payout ownership, agreed monthly pricing, refund terms, and whether future automatic subscriptions are desired.
4. Team email provider and verified sender address. Resend is prepared but no account has been created or connected.
5. Organizer contact, privacy/retention procedures, and approval of the remaining clearly labeled draft consent documents. They have not been represented as final agreements.

## Release steps after confirmation

1. Keep the original VZN Worker and HoodFlyLog unchanged as rollback references. Create a separate Git repository under team ownership using this folder, excluding local credentials, node_modules, and `.wrangler`.
2. Review `supabase/production_billing_notifications.sql`. Apply it ONCE in a transaction to the confirmed existing VZN project. Preserve existing tables and accounts. The other SQL files are historical snapshots, not a migration sequence; the obsolete bootstrap is archived. Use the Supabase CLI to generate proper migration history when recording the approved release.
3. Configure Supabase Auth Site URL `https://vznelite.org/` and allow exactly that root plus `https://vznelite.org/?flow=recovery`. Add the new team's workers.dev test URLs separately if used. Keep email confirmation enabled. Configure SMTP and enable leaked-password protection if supported. Remove old redirects only after recovery/sign-in work on the new domain.
4. Add the confirmed destination `account_id` to `wrangler.jsonc`. The release command refuses the source personal account. Domain routes are intentionally absent; inspect existing DNS before adding the custom domain.
5. Set secrets through the destination Cloudflare secret UI or protected CLI input: `SUPABASE_SERVICE_ROLE_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `RESEND_API_KEY`. Never place them in public files, Git, or chat. Set non-secret `MAIL_FROM` to the verified sender. Keep both enable flags false initially.
6. Deploy with `npm run deploy` to the team account only, after approval. A static folder/ZIP upload alone is insufficient: the backend Worker is required for checkout and email delivery.
7. Connect the approved custom domain `vznelite.org` to the new Worker after DNS review. Register Stripe webhook `https://vznelite.org/api/stripe-webhook` for `checkout.session.completed` and `checkout.session.async_payment_succeeded`. Use matching Stripe test/live credentials and webhook secret.
8. Complete test-mode acceptance below, then explicitly approve enabling `PAYMENTS_ENABLED` and `NOTIFICATIONS_ENABLED`. These are configuration changes requiring redeployment; maintain them in versioned configuration.

## Acceptance before enabling families and payments

- Create two parent test accounts, a player invited by one guardian, and a separate administrator. Confirm verification, sign-in, password reset, and logout on the final domain. No real credentials or emails were submitted during local browser verification.
- Confirm pending users cannot read the roster or calendar, a parent cannot read another family's invoices or update another player's records, and players cannot give parent consent or grant roles.
- Confirm sibling selection and multiple guardians; assign exactly one approved billing parent per player. Existing invoices stay assigned to their original payer.
- Issue a test monthly invoice, verify support, reject a duplicate month, and confirm Stripe charges the invoice amount regardless of browser input. Complete successful and failed test payments, callback retries, and cancelled checkout. Verify paid status only after webhook delivery.
- Verify new-account email reaches every current administrator. Test a disabled sender and retry recovery. Test SMTP confirmation/recovery and the existing invite-player function independently.
- Review real schedule/venue information privately, draft policies, organizer contact, and refund process. Do not publish children's personal records.

## Verification performed

- Automated tests cover calendar dates/DST, dues and ledger calculations, conflict detection, family billing summaries, webhook signatures, invoice ownership, origin checks, immutable checkout amount, session reuse, unpaid-event rejection, and administrator email recipients.
- Transactional database assertions passed for invoice creation permissions, duplicate prevention, parent isolation, blocked self-payment updates, service-only receipt recording, amount matching, webhook replay, notification visibility, and queue leases. Setup and fixtures were rolled back together. Existing production schema/data were preserved.
- Cloudflare's pinned build tool passed a deployment dry run; no upload occurred. A local Worker served the page with security headers. Desktop/mobile homepage, registration, and recovery navigation were inspected in the browser.
- Live checkout, final-domain auth redirects, SMTP/Resend delivery, and hosted multi-account acceptance remain pending configuration and deployment.

## Handoff and rollback

Keep domain registration, Cloudflare, Supabase, Stripe, and email in team-controlled accounts with at least two individual owners, recovery details in a shared password manager, and no shared personal passwords. Use individual website administrator roles; the existing role manager protects the last administrator. Keep a private Git repository, dependency lockfile, deployment records, and periodic database/private-storage backups. Never mix HoodFlyLog data, credentials, DNS, or resources into this project.

If the new site has a problem, disable its payment/notification flags and roll back its Worker version. Database changes are separate from Worker rollback; preserve invoices and payment events and reconcile provider records. Do not delete or reset databases. No shutdown of HoodFlyLog is needed for this transfer.

## Email-only rollout

Resend domain vznelite.org was shown verified by the owner. A sending key was saved encrypted locally. Use admin_notifications_setup.sql for email-only setup; billing_setup.sql stays pending. Do not apply the original combined script after applying either split script. Supabase SMTP and the Worker sender/secrets still need configuration approval and delivery verification. Stripe remains disabled.
