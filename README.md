# ASP Marketplace Deployment

Public deployment assets for the **CodSec ASP** platform — a self-hosted chat UI plus backend API.

This repository contains the **infrastructure-as-code** and Helm charts needed to deploy the ASP frontend and backend into your own Google Cloud project. Application source code and integrations are not included; this repo is the deployment glue only.

## What gets deployed

- **GKE Autopilot** cluster
- **CloudSQL** PostgreSQL 16 instance
- **Memorystore** Redis instance
- **ASP backend** (FastAPI) — Helm chart
- **ASP frontend** (Next.js chat UI) — Helm chart

## Quickstart

```bash
# 1. Set required variables
export PROJECT_ID=your-gcp-project
export REGION=us-central1
export DOMAIN=asp.example.com

# 2. Verify environment
./scripts/preflight.sh

# 3. Deploy infrastructure + apps
./scripts/install.sh
```

Full walkthrough: [docs/install.md](docs/install.md).

## Documentation

- [Prerequisites](docs/prerequisites.md)
- [Install](docs/install.md)
- [Uninstall](docs/uninstall.md)

## Container images

Container images for the frontend and backend are distributed separately. Set the image references in `helm/frontend/values.yaml` and `helm/backend/values.yaml` to the tags provided with your subscription.

## Support

For licensing, image access, and support, contact CodSec at [support@codsec.io](mailto:support@codsec.io).

## License

Apache 2.0 — see [LICENSE](LICENSE).
