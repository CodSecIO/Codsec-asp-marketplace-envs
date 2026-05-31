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

- One domain, path-routed: `/api` -> backend, `/` -> frontend. The chat UI calls
  `${NEXT_PUBLIC_BASE_URL}/api` same-origin, and the backend serves under `/api`
  (health at `/api/health`).
- HTTPS only: a GKE ManagedCertificate is created for the domain and HTTP is
  disabled on the Ingress.
- secops-mcp is reachable only from the backend (default-deny NetworkPolicy).
- Deployer ServiceAccount is a namespaced Role scoped to the resources it creates.

## Layout

```
marketplace/
  schema.yaml                  # Marketplace inputs + image declarations + deployer RBAC
  deployer/Dockerfile          # FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm
  Makefile                     # build deployer, lint, verify
  chart/asp/templates/
    application.yaml           # Application CRD (required by Marketplace)
    backend.yaml frontend.yaml secops-mcp.yaml secret.yaml
    ingress.yaml               # ManagedCertificate + single path-routed Ingress
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

Two product-code dependencies (in `mcp-project` / `chat-ui-mcp-project`, which we
own - not blocked on another team):

- **Frontend backend URL is build-time.** `chat-ui` inlines `NEXT_PUBLIC_BASE_URL`
  at build, so a single Marketplace image cannot adapt to each customer's domain.
  The image needs to resolve the API base at runtime (e.g. `window.location.origin`
  or a runtime config endpoint). This is a small `chat-ui` change.
- **secops-mcp registration.** The backend reads MCP URLs from the `applications`
  DB table per permission set, not from an env var. The in-cluster URL
  `http://<name>-secops-mcp:8000` must be seeded there; confirm the seed mechanism.

Packaging items handled elsewhere:

- The `com.googleapis.cloudmarketplace.product.service.name` image annotation is a
  build-time `LABEL` on each image, so it goes in the `mcp-project` and
  `chat-ui-mcp-project` build, not this repo (separate PRs).
- `mpdev verify` on a throwaway GKE cluster.
- Producer Portal onboarding + image mirroring.
