# November payment reconciliation — November 1, 2026

Deployed to https://vznelite.org, Worker version 64109e42-95f3-4d26-b8e7-492fd2b374b2.

Administration > Finances now opens Payment reconciliation & Venmo receipts. It summarizes active players, paid status versus full sponsorship, imported unmatched receipts, and payment details needing verification. Existing receipt import, CSV preview, report review and assignment remain available. Finance totals show a provisional warning while payment details are outstanding.

Live Supabase cfxieoqafldmbrcibqwq:
- Steele Statton November marked paid from confirmed Marisol $50 payment. No invented net amount or transaction ID; gross confirmation retained in the existing administrator-only finances document reconciliation_pending list.
- Latest user clarification: Crystal Montgomery is Brandon Hood mother. Original receipt restored once, Brandon remains paid. Actual fee/net and transaction ID pending verification; the prior entered $50 remains provisional.
- Latest user clarification: Allen Post voluntarily paid $46.88. Original optional receipt restored once, superseded $46.99 correction voided with reason. AJ full sponsorship preserved; $0 required. Gross amount and fee are not established by this latest clarification.
- Kevin cash, Le Kent, Luke Beyer, Manolo Mendoza, Tyler Locke paid records preserved. Johann active remains without confirmed payment.
- Changes preserve receipt correction reasons and dues history. No new database schema, membership, provider settings, or outbound messages.

74 tests and syntax checks pass; deployment dry run passed. Cloudflare confirmed uploading four changed production assets and activating the version. Independent HTTP asset hash verification was blocked by HTTP 403; no hash match is claimed. Authenticated browser interaction was not exercised with a real admin login. Existing Tina/Joshua/Crystal Venmo amounts were entered as $50 net without actual fee evidence; finance totals need statement reconciliation. Steele income is excluded pending actual net. Do not import payments already represented in player_contributions again: use corrections and verified transaction references to avoid duplicate income.

This workspace is not a Git checkout. Deployment used the existing installed Wrangler 4.151.1 at C:/projects/VZNElite/node_modules, targeting the verified team account. Canonical C:/projects checkout and GitHub were not synchronized by this task.

Update: Administrator confirmed all six regular November Venmo dues payments were 50.00 gross / 1.05 fee / 48.95 net. Existing receipts corrected without duplication and Steele net receipt backfilled once. Full 50.00 dues credits preserved. Kevin cash 50.00 and Allen voluntary 46.88 preserved. Combined recorded cash is 390.58 (Venmo 340.58 plus cash 50.00); pending amount checks resolved. Transaction IDs remain unavailable. Changes applied directly to live Supabase; no code deployment required.
