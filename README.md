# CodSec ASP - Google Cloud Marketplace deployment assets

Public deployment assets and documentation for the **CodSec ASP** (Agentic Security
Platform) listing on Google Cloud Marketplace - a self-hosted chat UI plus backend API.

This repository is the public reference that the Marketplace listing points at. The
deployer package that Marketplace runs lives in [`marketplace/`](marketplace/).

## What gets deployed

A single release into your GKE cluster:

- **frontend** - Next.js chat UI, served at `/`
- **backend** - FastAPI API, served at `/api` (health at `/api/health`)

ASP connects to a **PostgreSQL 16** database and a **Redis** instance that you bring
yourself (a managed service such as Cloud SQL + Memorystore, or your own) - the package
does not run them in-cluster. You provide their connection details at deploy time.

One domain, path-routed (`/api` to the backend, `/` to the frontend), HTTPS via a GKE
managed certificate (HTTP is redirected to HTTPS). On install the chart runs the database
migrations and creates your admin user automatically, so you can log in right away. You
set the domain, an admin email/password, and your PostgreSQL + Redis connection details;
the JWT secret and admin API key are generated, and a Google API key is optional (the
chat agent needs it).

> The backend connects to PostgreSQL without TLS, so the database must accept non-TLS
> connections (for example Cloud SQL reached over private IP). Redis can optionally use a
> password and TLS.

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
