# Releasing the ASP classic Marketplace product (internal runbook)

> Maintainer / DevOps handoff doc. The customer-facing deployer package is in
> `marketplace/`. All commands below run from `marketplace/`.

The product is a Google Cloud Marketplace **classic Kubernetes app**: customers deploy
ASP into their own GKE cluster, and the deployer installs the Helm chart in
`marketplace/chart/asp` - frontend, backend, a migration Job (`alembic upgrade head`), and
a bootstrap Job that creates the first admin. PostgreSQL + Redis are **bring-your-own**
(the customer supplies connection details; nothing data-tier runs in-cluster).

Producer Portal product (project `codsec-public`): service name
`asp-codsec.endpoints.codsec-public.cloud.goog`. Images in
`us-docker.pkg.dev/codsec-public/asp-deployer`:

- `asp` - backend (the primary image)
- `asp/frontend` - frontend
- `asp/backoffice` - backoffice
- `asp/redis` - redis
- `asp/deployer` - the deployer (bakes a snapshot of the chart; see below)

Pushing to this registry needs a `codsec.io` Google account with access to the
`codsec-public` project.

Producer Portal listing:
https://console.cloud.google.com/producer-portal/listing-edit/asp-codsec.endpoints.codsec-public.cloud.goog;stepId=publish?project=codsec-public

Google sends Marketplace vulnerability notices to sales@codsec.io. Each names the CVEs,
the flagged image digest and a fix deadline; a fix ships as a new release (below).

## What a customer deploys, and the inputs

Console one-click from the listing, or the CLI path in `docs/install.md`. Inputs:
`domain`, `adminEmail`, and the PostgreSQL + Redis connection details (`db.host`,
`db.password`, `redis.host` required; `db.port`/`db.user`/`db.name`/`redis.port` default;
`redis.password`/`redis.tls` optional) are required; `adminPassword`, `jwtSecret`, and the
admin `apiKey` are generated if left blank; `googleApiKey` is optional (the chat agent
needs it). The backend connects to PostgreSQL without TLS. On install the migration Job
runs, then the bootstrap Job registers the admin via the api-key, so the customer logs in
at `https://<domain>` with `adminEmail` / `adminPassword`.

## CRITICAL: the deployer image bakes the chart

`deployer/Dockerfile` is `FROM .../deployer_helm/onbuild`, which COPIES `chart/` +
`schema.yaml` INTO the image at build time. The Marketplace deployer runs that baked
snapshot, NOT this repo. So after ANY change under `chart/` or `schema.yaml` you MUST
rebuild the deployer image, re-annotate it, and re-point the Portal release. Editing the
repo alone changes nothing that customers run.

## Release steps

Tools: docker (with buildx), helm, crane, mpdev, trivy.

0. **Bump the version** in `Makefile` (`VERSION`), `chart/asp/Chart.yaml`,
   `chart/asp/values.yaml` (`publishedVersion` and every image `tag`) and `schema.yaml`
   (`publishedVersion`). Fixes to the deployer itself go in `deployer/Dockerfile`.
1. **Lint:** `make lint`
2. **Build + push the deployer** (amd64, single-manifest so it runs on GKE and crane can
   annotate it): `make deployer`
3. **Annotate** the deployer with the product service name - a manifest annotation, not a
   Dockerfile LABEL: `make annotate`
   - If you also rebuilt an app image, re-annotate it the same way:
     `crane mutate <image>:<version> --annotation com.googleapis.cloudmarketplace.product.service.name=services/asp-codsec.endpoints.codsec-public.cloud.goog`
   - Tag the app images that did not change with the new version (same digest, so the
     annotation carries over), for each of `asp`, `asp/frontend`, `asp/backoffice`,
     `asp/redis`:
     `crane tag us-docker.pkg.dev/codsec-public/asp-deployer/<image>:<old> <new>`
   - Scan the pushed deployer before submitting:
     `trivy image --scanners vuln us-docker.pkg.dev/codsec-public/asp-deployer/asp/deployer:<new>`
4. **Verify** on a throwaway GKE cluster: `make verify` (installs the deployer, runs the
   apptest tester, uninstalls). The apptest overlay (`apptest/deployer/schema.yaml`)
   supplies headless defaults for `domain` / `adminEmail` and points the `db`/`redis`
   inputs at the ephemeral PostgreSQL + Redis fixtures the apptest chart spins up (so verify
   exercises the real BYO path without needing an external database). Use a STANDARD
   pre-provisioned cluster - Autopilot churns the burst of pods.
5. **Producer Portal** (listing link above), **Container images** step:
   1. Click **Edit Content**, then **Edit** next to *Proposed releases* and **Continue**.
   2. Delete the existing release (trash icon) and click **Add a Release**.
   3. **Display Tag**: pick the track (e.g. `1.6`) whose digest matches the deployer you
      just pushed. An entry marked *Out of sync* is the old digest; do not pick it.
   4. Fill in:
      - Version title: the track, e.g. `1.6`
      - Description: `CodSec ASP: chat UI + backend API. BYOC.`
      - Public git repo URL: `https://github.com/CodSecIO/Codsec-asp-marketplace-envs`
      - Deploy documentation URL:
        `https://github.com/CodSecIO/Codsec-asp-marketplace-envs/blob/main/docs/install.md`
      - Default Release: the new release
   5. **Save and Validate**. Validation (schema extraction, a test deployment and a
      vulnerability scan) can take up to 2 hours. If it fails, fix, push a new version
      and repeat from step 0.
   6. When validation succeeds, **Submit**. Once the section is approved, go to
      **Publish** and publish the listing.

> Marketplace snapshots a release immutably per Display Tag + Version. If you change an
> image, that produces a new digest (re-annotate it) and needs a new release; re-pushing
> the same tag does not refresh a release that was already submitted.

## Verified

`make verify` installs the deployer on a standard GKE cluster, where the apptest chart
brings up ephemeral PostgreSQL + Redis that the BYO inputs point at, then runs the flow
end-to-end: migration Job -> backend Ready -> bootstrap creates the admin -> tester checks
`/api/health` + the frontend -> teardown. `helm lint` and `kubeconform` pass.
