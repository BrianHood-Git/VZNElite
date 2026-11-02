# Production security review — October 18, 2026 (Central)

Target: https://vznelite.org, team Cloudflare account 5c052106020fdea2cdd13759f2b95ad3, Supabase cfxieoqafldmbrcibqwq.

## Applied and verified

- Fixed a column authorization gap: parents/players can edit their linked profile fields but cannot change billing parent, player identity, or roster status. Coaches cannot directly change billing responsibility. Existing checked administrator workflows still work.
- Consent insert timestamps are assigned by the database, preventing clients from creating future-dated records that override subsequent consent history.
- HTTP redirects to HTTPS with 308. HTTPS responses include HSTS (one year, current hostname only), frame protection, no-sniff, and the existing restrictive content security policy.
- Added cross-origin isolation headers for static assets and no-store security headers to API responses.
- Added Cloudflare rate limiting to non-webhook website API requests (60 requests/minute/IP, best effort). This does not rate-limit direct Supabase authentication traffic.
- Confirmed all public application tables have row-level security enabled; private photos remain in a non-public bucket with a 5 MB/type restriction. No server credentials found in first-party browser source.
- Confirmed email confirmation is required and anonymous authentication is disabled.
- Dependency audit: no known vulnerabilities reported at review time.
- 32 application tests passed. Database rollback tests cover self-promotion, cross-family edits, protected billing/status fields, private data, timestamp spoofing, and unapproved-account access. Live HTTP/HTTPS and API headers verified.

## Still outstanding

- Integrate CAPTCHA on registration, password login, and recovery, then enable native Supabase CAPTCHA enforcement. Never enable the backend requirement ahead of a working frontend; it would block existing users. Native Supabase enforcement is necessary to protect its directly accessible auth API.
- Supabase advisor reports leaked-password protection disabled; enable if available on the current plan.
- Review authentication rate limits, redirect allowlists, session configuration, and dashboard MFA using the authenticated Supabase dashboard. Existing connector does not expose Auth configuration changes.
- Confirm Cloudflare and Supabase account MFA and recovery ownership. Current Cloudflare token cannot read zone SSL/TLS settings (403); HTTP enforcement was implemented in the Worker instead.
- Off-site backups and owner recovery/handoff remain on the backlog.

No passwords, birthdays, or family records were changed by testing. Test data was rolled back. This is a scoped hardening pass, not a guarantee against every vulnerability.
