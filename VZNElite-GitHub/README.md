# VZN Elite

Current deployed source recovered and updated October 21, 2026. See VENMO-UPDATE.md for contribution reporting, CSV import, applied migrations, validation and deployment details.

Run npm run check and npm test. The browser uses production Supabase configuration; use isolated/rolled-back fixtures for tests. Do not rerun SQL migrations already applied. Secrets are kept remotely and are not included.
