# ASP Marketplace deployer package

Google Cloud Marketplace **classic Kubernetes app** package for CodSec ASP.

This is the one-click install path for the Marketplace listing. The repo root
(docs) remains the public reference deploy and the required public
documentation URL; this `marketplace/` directory is the deployer package.

## Model

- Classic Kubernetes app: the deployer installs in-cluster resources only.
- PostgreSQL and Redis are **bundled in-cluster** (demo-grade: single replica,
  one PVC for Postgres, no HA or managed backups). This keeps the package
  self-contained so it installs with no external prerequisites. Production
  deployments should point at managed data services - contact CodSec. The required
  inputs are `domain` and `adminEmail`; `adminPassword`, `dbPassword`, `jwtSecret`,
  and the admin `apiKey` are auto-generated if left blank, and `googleApiKey` is
  optional (the chat agent needs it).
- Two app images + bundled data services:

  | Service | Image | Port |
  |---------|-------|------|
  | frontend (Next.js chat UI) | `chat-ui` | 3000 |
  | backend (FastAPI) | `secops-agent` | 8000 |
  | postgres (bundled) | `postgres:16-alpine` | 5432 |
  | redis (bundled) | `redis:7-alpine` | 6379 |

  > **secops-mcp is deprecated in this package for now.** The backend discovers
  > MCP servers from a DB `applications` table by per-tenant convention, and this
  > static bundle has no orchestrator to seed that registration, so a bundled
  > secops-mcp pod would never be reached. It is dropped until that wiring is
  > resolved (see Open items). Re-add `secops`/`secopsMcp.image` and the
  > `secops-mcp.yaml` template when it is.

- On install a migration Job runs `alembic upgrade head` and a bootstrap Job creates
  the first admin user (`adminEmail`/`adminPassword`) via the backend admin api-key,
  so the customer can log in immediately. The backend reads discrete `POSTGRES_*` /
  `REDIS_*` env set by the chart, not a connection URL.
- One domain, path-routed: `/api` -> backend, `/` -> frontend. The chat UI reads
  `SERVER_HOST` at runtime and calls `${SERVER_HOST}/api` same-origin; the backend
  serves under `/api` (health at `/api/health`).
- HTTPS: a GKE ManagedCertificate is created for the domain, and a FrontendConfig
  redirects HTTP to HTTPS. HTTP stays enabled because managed-cert provisioning and
  the redirect both require it (GKE forbids `allow-http:false` with managed certs).
- Deployer ServiceAccount is a namespaced Role scoped to the resources it creates.

## Layout

```
marketplace/
  schema.yaml                  # Marketplace inputs + image declarations + deployer RBAC
  deployer/Dockerfile          # FROM .../deployer_helm/onbuild (packages chart/ + schema.yaml)
  Makefile                     # build deployer, lint, verify
  chart/asp/                   # chart nested one level: onbuild needs a single chart dir
    Chart.yaml values.yaml
    templates/
      application.yaml         # Application CRD (required by Marketplace)
      backend.yaml frontend.yaml secret.yaml
      postgres.yaml redis.yaml # bundled in-cluster data services
      migrate-job.yaml         # alembic upgrade head (schema migrations)
      bootstrap-job.yaml bootstrap-configmap.yaml  # creates the first admin user
      ingress.yaml             # ManagedCertificate + FrontendConfig + path-routed Ingress
      networkpolicy.yaml       # default-deny scaffold (currently inert; see note above)
  apptest/deployer/asp/        # tester Pod for `mpdev verify`
  apptest/deployer/schema.yaml # verify-only defaults (domain, adminEmail)
```

## Build and verify (run by a human against a test GKE cluster)

```bash
cd marketplace
make lint                # helm lint + template
make deployer            # docker build + push the deployer image
mpdev verify --deployer="$REGISTRY/asp/deployer:$TRACK"
```

Install `mpdev` from https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools.

## Open items before submission

Two product-code items (in `mcp-project` / `chat-ui-mcp-project`, which we own):

- **chat-ui app-configs route runtime.** The chat UI already resolves its backend
  host at runtime from `SERVER_HOST` (via `/runtime/app-configs`), so this chart
  sets `SERVER_HOST=https://<domain>` and no rebuild is needed. But that route is
  `export const runtime = 'edge'`, which in self-hosted standalone only reads
  runtime env via an undocumented startup snapshot. Change it to `runtime = 'nodejs'`
  (the default) for a reliable request-time read. One-line fix.
- **secops-mcp registration — BLOCKED, MCP dropped from this package for now.** The
  backend resolves a self-hosted MCP's URL by convention as
  `http://<app>.tools-<permission_set_id>-<ENV>.svc.cluster.local:8000` (per-tenant,
  provisioned dynamically by the asp-infrastructure-orchestrator). A static bundle
  has no orchestrator, so the backend would never find a bundled MCP. Rather than
  ship a pod that is never reached, secops-mcp is removed from the chart/schema and
  the package ships frontend + backend only. To bring it back, `secops` must be
  registered as `remote=true` with `MCP_URL=http://<name>-secops-mcp:8000` (plus
  MCP_URL validators + AUTH_TYPE) so the backend uses the remote-MCP path — a
  backend migration/seed change in mcp-project — then re-add the image declaration,
  values, and `secops-mcp.yaml` template here.

Packaging items handled elsewhere:

- The `com.googleapis.cloudmarketplace.product.service.name` image annotation must be a
  manifest annotation (not a Dockerfile `LABEL`) on the deployer and every application
  image, pointing at the product service name. Apply it with `crane mutate --annotation`,
  or durably with `docker buildx build --annotation` in the `mcp-project` and
  `chat-ui-mcp-project` pipelines. See `RELEASING.md`.
- `mpdev verify` on a throwaway GKE cluster.
- Producer Portal onboarding + image mirroring.
