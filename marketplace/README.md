# ASP Marketplace deployer package

Google Cloud Marketplace **classic Kubernetes app** package for CodSec ASP.

This is the one-click install path for the Marketplace listing. The repo root
(Terraform + docs) remains the public reference deploy and the required public
documentation URL; this `marketplace/` directory is the deployer package.

## Model

- Classic Kubernetes app: the deployer installs in-cluster resources only.
- The customer brings their own PostgreSQL and Redis and supplies connection
  details at deploy time. The deployer does not provision managed services.
- Three services, each its own image:

  | Service | Image (`mcp-ai-shared/mcp-ai-registry/...`) | Port |
  |---------|----------------------------------------------|------|
  | frontend (Next.js chat UI) | `chat-ui` | 3000 |
  | backend (FastAPI) | `secops-agent` | 8000 |
  | secops-mcp | `secops` | 8000 |

- One domain, path-routed: `/api` -> backend, `/` -> frontend. The chat UI reads
  `SERVER_HOST` at runtime and calls `${SERVER_HOST}/api` same-origin; the backend
  serves under `/api` (health at `/api/health`).
- HTTPS: a GKE ManagedCertificate is created for the domain, and a FrontendConfig
  redirects HTTP to HTTPS. HTTP stays enabled because managed-cert provisioning and
  the redirect both require it (GKE forbids `allow-http:false` with managed certs).
- secops-mcp is reachable only from the backend (default-deny NetworkPolicy).
- Deployer ServiceAccount is a namespaced Role scoped to the resources it creates.

## Layout

```
marketplace/
  schema.yaml                  # Marketplace inputs + image declarations + deployer RBAC
  deployer/Dockerfile          # FROM .../deployer_helm/onbuild (packages chart/ + schema.yaml)
  Makefile                     # build deployer, lint, verify
  chart/templates/
    application.yaml           # Application CRD (required by Marketplace)
    backend.yaml frontend.yaml secops-mcp.yaml secret.yaml
    ingress.yaml               # ManagedCertificate + FrontendConfig + path-routed Ingress
    networkpolicy.yaml         # default-deny to secops-mcp
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
- **secops-mcp registration (backend/product decision, not packaging).** The
  backend resolves a self-hosted MCP's URL by convention as
  `http://<app>.tools-<permission_set_id>-<ENV>.svc.cluster.local:8000` (per-tenant,
  provisioned dynamically by the asp-infrastructure-orchestrator). This bundle
  deploys one static `<name>-secops-mcp:8000` and has no orchestrator, so the
  backend will not find it at that URL. To wire it up, `secops` must be registered
  as `remote=true` with `MCP_URL=http://<name>-secops-mcp:8000` (plus MCP_URL
  validators + AUTH_TYPE) so the backend uses the remote-MCP path - a backend
  migration/seed change in mcp-project, confirm with the backend owner.

Packaging items handled elsewhere:

- The `com.googleapis.cloudmarketplace.product.service.name` image annotation is a
  build-time `LABEL` on each image, so it goes in the `mcp-project` and
  `chat-ui-mcp-project` build, not this repo (separate PRs).
- `mpdev verify` on a throwaway GKE cluster.
- Producer Portal onboarding + image mirroring.
