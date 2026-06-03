# ASP Marketplace deployer package

Google Cloud Marketplace **classic Kubernetes app** package for CodSec ASP.

This is the one-click install path for the Marketplace listing. The repo root
(Terraform + docs) remains the public reference deploy and the required public
documentation URL; this `marketplace/` directory is the deployer package.

## Model

- Classic Kubernetes app: the deployer installs in-cluster resources only.
- The customer brings their own PostgreSQL and Redis and supplies connection
  details at deploy time. The deployer does not provision managed services.
- Two services, each its own image:

  | Service | Image (`mcp-ai-shared/mcp-ai-registry/...`) | Port |
  |---------|----------------------------------------------|------|
  | frontend (Next.js chat UI) | `chat-ui` | 3000 |
  | backend (FastAPI) | `secops-agent` | 8000 |

  > **secops-mcp is deprecated in this package for now.** The backend discovers
  > MCP servers from a DB `applications` table by per-tenant convention, and this
  > static bundle has no orchestrator to seed that registration, so a bundled
  > secops-mcp pod would never be reached. It is dropped until that wiring is
  > resolved (see Open items). Re-add `secops`/`secopsMcp.image` and the
  > `secops-mcp.yaml` template when it is.

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
  chart/templates/
    application.yaml           # Application CRD (required by Marketplace)
    backend.yaml frontend.yaml secret.yaml
    ingress.yaml               # ManagedCertificate + FrontendConfig + path-routed Ingress
    networkpolicy.yaml         # default-deny scaffold (currently inert; see note above)
  apptest/deployer/asp/        # tester Pod for `mpdev verify`
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

- The `com.googleapis.cloudmarketplace.product.service.name` image annotation is a
  build-time `LABEL` on each image, so it goes in the `mcp-project` and
  `chat-ui-mcp-project` build, not this repo (separate PRs).
- `mpdev verify` on a throwaway GKE cluster.
- Producer Portal onboarding + image mirroring.
