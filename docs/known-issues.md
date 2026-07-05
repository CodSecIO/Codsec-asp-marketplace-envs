# Known issues

## First-admin bootstrap fails on v0.11+ app images (release blocker)

**Symptom.** Marketplace "Save and validate" (and `mpdev verify`) fails with the
deployer timing out after 900s. The app itself comes up: `migrate` completes and
`backend`, `frontend`, and the bundled `redis` all reach Running. The blocker is the
`{release}-bootstrap` Job, which loops on:

```
register retry: 401 {"detail":"Unauthorized: Invalid or missing authentication token or api-key."}
could not create admin user
```

The deployer waits for that Job to complete, it never does, so the whole install is
marked failed.

**Root cause.** The bundled bootstrap Job creates the first admin by calling
`POST /api/auth/local/register` with the admin **api-key** (env `API_KEY`) in the
`api-key` header. That flow no longer works against a production install:

- The env-var api-key is only accepted when `MCP_ENVIRONMENT_TYPE` is `local` or `dev`
  (`modules/auth/middleware.py`). This chart runs `prod`, so the header is ignored and
  the request is rejected before it reaches the endpoint. This gate is present in every
  app release we can ship (v0.10, v0.10.1, v0.11, v0.12), so pinning to an older image
  does **not** work around it.
- In v0.12 the endpoint was hardened further: `/register` now requires an existing
  `MASTER_TENANT_ADMIN` caller and a `tenant_id` in the body, and `register_user`
  creates a plain tenant user (it never grants the master-admin type). So even with a
  valid caller, v0.12 cannot mint the *first* admin this way.
- v0.12's intended first-admin path is SSO: `POST /api/settings/bootstrap`
  (gated by `BOOTSTRAP_API_KEY`, refuses once an admin exists) seeds the master-tenant
  SAML config, and the first person to log in through that SAML flow is provisioned as
  `MASTER_TENANT_ADMIN`. There is no local email/password equivalent.

**Why `MCP_ENVIRONMENT_TYPE=dev` is not an acceptable fix.** Dev mode is a real
security downgrade for a customer install, not just a config flip:

- The env-var api-key becomes a valid global credential, and in dev mode a request
  authenticated with it is granted **all agent tool calls** with no permission check
  (`security_wrapper_middleware.py`).
- Agent tool-output redaction is disabled (`base_agent.py` stops masking TOOL content).

So we will not ship customers a `dev`-mode install.

**Required fix (app side).** Add a production-safe first-admin bootstrap that mirrors
the existing `/api/settings/bootstrap` pattern: a public endpoint gated by
`BOOTSTRAP_API_KEY`, that refuses once an active `MASTER_TENANT_ADMIN` exists and
otherwise creates a **local** `MASTER_TENANT_ADMIN` from an email + password. The
deployer already provisions `BOOTSTRAP_API_KEY`, the admin email, and the generated
admin password, so the chart's bootstrap Job would switch to that endpoint with no
schema change.

**Alternative (no app change).** Make the listing SAML-only: collect the customer's IdP
metadata as install inputs, seed master-tenant SAML via `/api/settings/bootstrap`, and
document that the first admin logs in through SSO. Heavier customer setup (requires an
IdP), and no local login.

**Status.** The Marketplace release is blocked until one of the above lands. The
shell-less-image init fix (see PR) is unrelated and already in.
