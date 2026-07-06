# Known issues

## First admin is SAML SSO only (no local email/password admin)

ASP runs on the v0.12 app images (CVE-clean, Chainguard base). In v0.12 there is
**no way to create a local email/password admin**: `/api/auth/local/register` is
gated to an existing master admin and only ever creates a regular tenant user, and
no CLI, seed, or "first user becomes admin" path exists. The **only** way to get the
first `MASTER_TENANT_ADMIN` is a **SAML SSO login**.

So the deployer no longer ships the old api-key bootstrap Job (it could not create an
admin on v0.12 and made the install hang). The app installs with **zero users**, which
is healthy, `/api/health` only checks Postgres + Redis, so the Marketplace test
deployment passes. The first admin is created **after install** by seeding the
master-tenant SAML config and logging in through the customer's IdP.

See `docs/install.md` for the first-admin setup steps. The chart generates a
`BOOTSTRAP_API_KEY` and exposes it on the backend so that call can be made.

**Implication for the listing:** ASP on v0.12 requires the customer to have a SAML IdP
(Okta, Azure AD, Google Workspace, etc.). A simple out-of-the-box email/password login
would need a local first-admin bootstrap added on the app side (not available in v0.12).

**Not yet automated (follow-up):** the chart does not yet collect the IdP metadata as
install inputs or generate the SP keypair, so the SAML setup is an operator step today.
Wiring it into the schema (turnkey SSO) is a possible follow-up.
