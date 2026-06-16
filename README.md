# CodSec ASP - Google Cloud Marketplace deployment assets

Public deployment assets and documentation for the **CodSec ASP** (Agentic Security
Platform) listing on Google Cloud Marketplace - a self-hosted chat UI plus backend API.

This repository is the public reference that the Marketplace listing points at. The
deployer package that Marketplace runs lives in [`marketplace/`](marketplace/).

## What gets deployed

A single release into your GKE cluster:

- **frontend** - Next.js chat UI, served at `/`
- **backend** - FastAPI API, served at `/api` (health at `/api/health`)
- **PostgreSQL** - bundled in-cluster (demo-grade: single replica, one PVC, no HA or backups)
- **Redis** - bundled in-cluster (demo-grade: ephemeral cache)

One domain, path-routed (`/api` to the backend, `/` to the frontend), HTTPS via a GKE
managed certificate (HTTP is redirected to HTTPS). On install the chart runs the database
migrations and creates your admin user automatically, so you can log in right away. You
set the domain and an admin email/password; the database password, JWT secret, and admin
API key are generated, and a Google API key is optional (the chat agent needs it).

> Bundled PostgreSQL and Redis are demo-grade. For production, point ASP at managed data
> services - contact CodSec.

## Deploy

- **Google Cloud Marketplace (recommended):** deploy from the ASP listing. Marketplace
  mirrors the images into your project and runs the deployer.
- **Command line:** see [docs/install.md](docs/install.md).

## Documentation

- [Prerequisites](docs/prerequisites.md)
- [Install](docs/install.md)
- [Uninstall](docs/uninstall.md)

## Container images

ASP frontend and backend images are distributed through your Marketplace subscription. To
pull them directly for a command-line install, contact CodSec for Artifact Registry access.

## Support

For licensing, image access, and support, contact CodSec at
[support@codsec.io](mailto:support@codsec.io).

## License

Apache 2.0 - see [LICENSE](LICENSE).
