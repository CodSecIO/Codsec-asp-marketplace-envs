# Releasing the ASP classic Marketplace product (internal runbook)

> Maintainer / DevOps handoff doc. The customer-facing deployer package is in
> `marketplace/`. All commands below run from `marketplace/`.

The product is a Google Cloud Marketplace **classic Kubernetes app**: customers deploy
ASP into their own GKE cluster, and the deployer installs the Helm chart in
`marketplace/chart/asp` - frontend, backend, bundled in-cluster PostgreSQL + Redis, a
migration Job (`alembic upgrade head`), and a bootstrap Job that creates the first admin.

Producer Portal product (project `codsec-public`): service name
`asp-codsec.endpoints.codsec-public.cloud.goog`. Images in
`us-docker.pkg.dev/codsec-public/asp-deployer`:

- `asp` - backend (the primary image)
- `asp/frontend` - frontend
- `asp/deployer` - the deployer (bakes a snapshot of the chart; see below)

## What a customer deploys, and the inputs

Console one-click from the listing, or the CLI path in `docs/install.md`. Inputs:
`domain` and `adminEmail` are required; `adminPassword`, `dbPassword`, `jwtSecret`, and
the admin `apiKey` are generated if left blank; `googleApiKey` is optional (the chat
agent needs it). On install the migration Job runs, then the bootstrap Job registers the
admin via the api-key, so the customer logs in at `https://<domain>` with
`adminEmail` / `adminPassword`.

## CRITICAL: the deployer image bakes the chart

`deployer/Dockerfile` is `FROM .../deployer_helm/onbuild`, which COPIES `chart/` +
`schema.yaml` INTO the image at build time. The Marketplace deployer runs that baked
snapshot, NOT this repo. So after ANY change under `chart/` or `schema.yaml` you MUST
rebuild the deployer image, re-annotate it, and re-point the Portal release. Editing the
repo alone changes nothing that customers run.

## Release steps

Tools: docker (with buildx), helm, crane, mpdev.

1. **Lint:** `make lint`
2. **Build + push the deployer** (amd64, single-manifest so it runs on GKE and crane can
   annotate it): `make deployer`
3. **Annotate** the deployer with the product service name - a manifest annotation, not a
   Dockerfile LABEL: `make annotate`
   - If you also rebuilt an app image, re-annotate it the same way:
     `crane mutate <image>:1.0 --annotation com.googleapis.cloudmarketplace.product.service.name=services/asp-codsec.endpoints.codsec-public.cloud.goog`
4. **Verify** on a throwaway GKE cluster: `make verify` (installs the deployer, runs the
   apptest tester, uninstalls). The apptest overlay (`apptest/deployer/schema.yaml`)
   supplies headless defaults for `domain` / `adminEmail`.
5. **Producer Portal** (codsec-public):
   - Container images -> Deployer image URL
     `us-docker.pkg.dev/codsec-public/asp-deployer/asp/deployer`.
   - New Release: Display Tag `1.0`, Version title `1.0`. Confirm the **deployer digest**
     matches the one you just pushed ("Change Deployer Image" and re-enter if you rebuilt).
   - Public git repo URL = this repo; Deploy documentation URL = `docs/install.md`.
   - Submit the Container Images review early - it can take two or more weeks.

> Marketplace snapshots a release immutably per Display Tag + Version. If you change an
> image, that produces a new digest (re-annotate it) and needs a new release; re-pushing
> the same tag does not refresh a release that was already submitted.

## Verified

The chart was deployed end-to-end on a GKE cluster: postgres -> migration Job -> backend
running -> bootstrap creates the admin -> admin login returns a JWT. `helm lint` and
`kubeconform` pass.
