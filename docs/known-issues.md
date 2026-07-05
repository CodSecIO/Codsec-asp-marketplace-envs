# Known issues

## 1.3 is pinned to v0.11 app images; v0.12 breaks the first-admin bootstrap

**Short version.** The bundled `{release}-bootstrap` Job creates the first admin by
calling `POST /api/auth/local/register` with the admin api-key. That works on **v0.11**
and earlier, and is broken on **v0.12**. So the 1.3 release ships the **v0.11** backend
(`secops-agent`) and frontend (`chat-ui`) images. The bundled Redis 8 image is
independent of the app version.

**What v0.12 changed.** On v0.11, `/api/auth/local/register` is a public endpoint (it is
in the auth middleware's `EXCLUDED_PATHS`), and its own guard simply checks the `api-key`
header against the `API_KEY` env var, with no environment gate. The deployer sets
`API_KEY`, so the bootstrap Job authenticates and creates the admin.

v0.12 locked this path down:

- `/api/auth/local/register` was removed from `EXCLUDED_PATHS`, so it now goes through the
  auth middleware. The middleware only honours the env-var api-key when
  `MCP_ENVIRONMENT_TYPE` is `local`/`dev`; this chart runs `prod`, so the header is
  ignored and the request is rejected with 401.
- The endpoint also gained `@require_user_type(MASTER_TENANT_ADMIN)` and a required
  `tenant_id`, and `register_user` no longer grants the master-admin type. So even an
  authenticated caller can't mint the *first* admin this way.
- v0.12's intended first-admin path is SSO: `POST /api/settings/bootstrap` (gated by
  `BOOTSTRAP_API_KEY`, refuses once an admin exists) seeds the master-tenant SAML config,
  and the first person to log in through that SAML flow is provisioned as the admin.
  There is no local email/password equivalent.

Symptom when run against a v0.12 image: `migrate`, `backend`, `frontend`, and `redis`
all come up, but the bootstrap Job loops on
`401 ... Invalid or missing authentication token or api-key` and never completes, so the
deployer times out and Marketplace validation fails.

**Why `MCP_ENVIRONMENT_TYPE=dev` is not an acceptable workaround.** Dev mode is a real
security downgrade for a customer install, not just a config flip:

- In dev mode a request authenticated with the env-var api-key is granted **all agent
  tool calls** with no permission check (`security_wrapper_middleware.py`).
- Agent tool-output redaction is disabled (`base_agent.py` stops masking TOOL content).

So we do not ship a `dev`-mode install just to unblock the api-key path.

**To move 1.3 (or a later release) onto v0.12, the app side must add** a production-safe
first-admin bootstrap that mirrors the existing `/api/settings/bootstrap` pattern: a
public endpoint gated by `BOOTSTRAP_API_KEY` that refuses once an active
`MASTER_TENANT_ADMIN` exists and otherwise creates a **local** `MASTER_TENANT_ADMIN` from
an email + password. The deployer already provisions `BOOTSTRAP_API_KEY`, the admin
email, and the generated admin password, so the chart's bootstrap Job would just repoint
at it, with no schema change.
