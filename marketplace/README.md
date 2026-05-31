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

## Layout

```
marketplace/
  schema.yaml                  # Marketplace inputs + image declarations
  deployer/Dockerfile          # FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm
  Makefile                     # build deployer, install, verify
  chart/asp/                   # the chart the deployer installs
    templates/application.yaml # Application CRD (required by Marketplace)
    templates/{backend,frontend,secops-mcp,secret}.yaml
  apptest/                     # tester for `mpdev verify` (TODO)
```

## Build and verify (run by a human against a test GKE cluster)

```bash
cd marketplace
make deployer            # docker build + push the deployer image
mpdev install --deployer="$REGISTRY/asp/deployer:$TRACK" --parameters='{...}'
mpdev verify  --deployer="$REGISTRY/asp/deployer:$TRACK"
```

Install `mpdev` from https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools.

## Status / TODO

This is a reviewable scaffold, not yet `mpdev verify`-passing.

- [ ] Confirm backend health path (`/healthz`) and secops-mcp health (`/health`).
- [ ] Confirm how the backend registers the secops-mcp server (app-specific; the
      chart currently passes `SECOPS_MCP_URL` only).
- [ ] Add `com.googleapis.cloudmarketplace.product.service.name` annotation to the
      three images at build/push time (see Makefile note).
- [ ] Add the `apptest/` tester chart required by `mpdev verify`.
- [ ] Scope the deployer ServiceAccount RBAC (currently broad - see schema.yaml).
- [ ] Producer Portal onboarding + image mirroring.
