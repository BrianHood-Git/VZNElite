# VZN Elite to-do list

Future work only. The role, layout, and calendar changes below have not been implemented or deployed.

## Account views and combined roles

- [ ] Add a Team management / My family switch for members with both staff and parent roles.
- [ ] Support Administrator + Parent and Coach + Parent on one account; no duplicate accounts or separate logins.
- [ ] Team management shows only the tools allowed by the assigned administrator or coach role.
- [ ] My family shows linked children, schedules, availability, consent, dues, and payments under the existing family/billing permissions.
- [ ] Switching views changes the layout, never authorization. Enforce permissions in the database and server as well as the interface.
- [ ] Members with only one applicable role see the area they need without an unnecessary switch.
- [ ] Coaches do not automatically receive administrator or team-wide finance access just because they have children on the team.

## Member management and owner recovery

- [ ] Exclude the signed-in administrator from dropdowns for changing another member's roles or profile. Keep self-profile edits under My account.
- [ ] Show a useful empty state when no other eligible members exist; retain the signed-in member in the read-only access list, labeled You.
- [ ] Decide and enforce the self-role-change rules server-side, not only by hiding controls.
- [ ] Fix the garbled separator in member labels and prefer friendly display names over prominent UUIDs.
- [ ] Confirm the exact verified hrianbood account with the owner before granting owner-level protection.
- [ ] Design an explicit, transferable owner role that ordinary admins cannot grant or revoke; protect the last owner and audit transfers.
- [ ] Review and approve the owner/recovery design before changing live access.
- [ ] Document emergency recovery through the team-controlled Supabase dashboard/SQL Editor, including revoking a compromised admin and sessions.
- [ ] Preserve team ownership/recovery of Supabase and Cloudflare independently of website roles. Do not add hidden back doors, hardcoded email bypasses, or automatic first-user ownership.

## One-month schedule planning

- [ ] Confirm whether one month ahead means the selected calendar month or a rolling month from today.
- [ ] Default recurring practices to the agreed planning window; prevent accidental creation of later months.
- [ ] Decide how historical browsing and any staff override should work.
- [ ] Add a single Cancel remaining series action for recurring practices, with an affected-date preview and one confirmation.
- [ ] Prefer cancellation that preserves event history and availability; define separately whether permanent removal is ever needed.
- [ ] Add multi-date/event selection with checkboxes or toggles on mobile and desktop, plus Ctrl/Cmd-click as a desktop shortcut.
- [ ] Make it clear whether selected dates affect all events that day or individually selected events.
- [ ] Show selected counts, Clear selection, affected events, and a confirmation before bulk cancellation.
- [ ] Restrict bulk changes to authorized staff and make batches bounded and atomic.
- [ ] Test month boundaries, daylight-saving changes, already-cancelled events, and recurrence boundaries.

## Security and operational follow-up

- [ ] Add Turnstile to registration, sign-in, and password reset; enable verification in Supabase only after the website integration is ready.
- [ ] Review production HTTPS enforcement, available firewall/request-limit protections, and Cloudflare account two-factor authentication.
- [ ] Resolve Supabase's leaked-password-protection warning if the plan supports it.
- [ ] Finish organizer contact, privacy/retention/deletion procedures, and review the draft consent policies.
- [ ] Complete a multi-account parent/player/staff walkthrough, including invitations and family isolation.
- [ ] Establish team-owned Git access, database/private-storage backups, and recovery/handoff procedures.

## Payments — wait for Stripe approval

- [ ] Complete the Stripe application and obtain approval.
- [ ] Confirm team account/payout ownership, monthly pricing, and refund/cancellation procedures.
- [ ] Apply billing-only database setup after approval; do not rerun the already applied email migration.
- [ ] Configure matching test/live Stripe credentials and webhook; run payment acceptance tests before enabling collection.
- [ ] Decide later whether to add automatic subscriptions or automatic monthly invoice issuance. Current prepared invoices require individual monthly authorization.
- [ ] Plan refunds, disputes, off-site payment reconciliation, departure requests, and future-payment cancellation.

## Completed tonight

- [x] Deploy the independent VZN Elite website to the team Cloudflare account and https://vznelite.org/.
- [x] Remove the public demo portal and sample players/events.
- [x] Retain registration, roles, family links, private photos, schedules, availability, and admin tools.
- [x] Make the top-right sign-in button reflect the session and support sign-out.
- [x] Verify the Resend sending domain, configure SMTP and admin notifications, and confirm test email delivery.
- [x] Update production URLs and the player-invitation function; owner confirmed password reset works.
- [x] Keep Stripe disabled and HoodFlyLog resources separate.

Repository sync: this list is saved in the prepared local VZN Elite project. Remote GitHub commit has not been completed because the access attempt was blocked by a content filter.
