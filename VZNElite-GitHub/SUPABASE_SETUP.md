# Supabase setup status

Use LAUNCH.md as the current setup and release procedure. The existing VZN Elite project already has the account, family, roster, calendar, private-photo, and role schema. Do not run historical SQL snapshots or the archived bootstrap against it.

The only new pending setup is `supabase/production_billing_notifications.sql`. It was tested transactionally with `supabase/tests/production_billing.sql`, then fully rolled back. It has NOT been applied permanently. After destination approval, apply once in a transaction and record it in migration history using the Supabase CLI. The existing invite-player function also needs sender/redirect acceptance on the new domain.
