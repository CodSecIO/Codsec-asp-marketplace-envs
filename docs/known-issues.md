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
deployment passes. The first admin is created by the first SAML SSO login.

The first-admin SSO is now **auto-configured at install**. When you provide the IdP
inputs (`saml.idpEntityId`, `saml.idpSsoUrl`, `saml.idpX509Cert`), the chart generates
the SP keypair, wires the backend's SAML settings, and a post-install Job seeds the
master-tenant SAML config for you. The manual `POST /api/settings/bootstrap` call is
**only needed if those IdP inputs were left blank**. See `docs/install.md` for both paths.

**Implication for the listing:** ASP on v0.12 requires the customer to have a SAML IdP
(Okta, Azure AD, Google Workspace, etc.) that releases the user's email, first name, and
last name. A simple out-of-the-box email/password login would need a local first-admin
bootstrap added on the app side (not available in v0.12).

**Upgrade caveat (SP keypair):** a version upgrade may regenerate the SAML SP keypair;
persistence across upgrade is not yet verified. If it regenerates, the customer must
re-register the SP metadata at their IdP after the upgrade. This note is removed once an
upgrade test confirms the keypair is stable.
