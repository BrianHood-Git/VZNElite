# Next session

The complete current backlog is maintained in [TODO.md](TODO.md), including combined Coach/Parent and Administrator/Parent accounts, Team management / My family views, owner recovery, and bulk schedule management.

These changes remain future work. No live permissions or schedules were changed while recording this list.


## Team email notifications (2026-10-20)
- Administration announcements now mount independently of the shared calendar/workspace.
- New announcement posts and title/body edits queue emails; pinning/removal do not create emails. Pending removed/superseded posts are excluded from delivery.
- Practice reminders target 18:00 America/Chicago the preceding day; the existing five-minute Worker cron processes the queue and respects DST, cancellations, and active family links.
- `TEAM_EMAILS_ENABLED` controls the new worker sender. Sender stays notifications@vznelite.org via the existing Resend secret.
- Outbox is admin-readable, service-write-only; claimed batches have a five-minute lease and stable Resend idempotency keys. Ten attempts maximum; messages expire before the provider deduplication window ends.
- SQL: supabase/team_email_notifications.sql; rollback verification: supabase/tests/team_email_notifications.sql.


## Tournament planning and vendors (2026-10-28)
- Canonical C:/projects/VZNElite was reconciled with the verified live 2026-10-23 Venmo/family snapshot. Backup: .local-history/before-20261028-tournaments. The old C:/Users/TapeWorm/Documents/ChatGPT/VZNElite workspace was empty; its vendor task had made no changes.
- Admin Tournament vendors: searchable create/edit/archive directory and database audit history. Seeds are only the six user-supplied organizations/resources and supplied contact/website details.
- Tournaments: vendor selection, considering/registered/confirmed/completed/cancelled status, date range up to seven days, daily Central start time, registration deadline and link, existing cost/payment notes.
- Explicit Publish to team calendar requires Registered/Confirmed, date, time, and location. Subsequent saves synchronize linked daily events atomically; cancellation/archive cancels linked events, restoring retains event IDs and availability.
- Linked events are managed from Tournaments, not through independent calendar edits. Costs and private notes stay administrator-only. Coach contact access remains read-only. No offsite registration, payments, or outbound messages are initiated by this workflow.
- SQL: supabase/tournament_planning.sql. Rollback verification: supabase/tests/tournament_planning.sql.

Published tournament planning release: Worker version 2e313730-97e4-4399-ab10-a0d5b6ca1460. All 58 application tests and the transactional database access/calendar-sync checks passed. Production assets verified; six vendor entries seeded, existing tournament retained, and no real tournament was published during testing.

## Individual parent emails (2026-10-30)
- Administration > Email a parent: administrator-only composer, parent selector, contribution link helper, review before sending.
- Worker /api/parent-email verifies live user, current administrator and parent roles, verified recipient account; no client-supplied email address. Single-recipient Resend delivery returns provider message ID; acceptance is distinct from delivery. Stable per-attempt idempotency on unchanged retries.
- No automatic test email or parent mail sent during implementation. No schema/secrets/DNS changes.
- 65 tests pass and build passes. Production version acc3f6a5-ac78-4c68-b365-6c6da355adac. Live assets and unauthenticated 401 verified.

