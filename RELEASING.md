# Releasing the ASP classic Marketplace product (internal runbook)

> Maintainer documentation. The customer-facing deployer package is in `marketplace/`.

The product is a Google Cloud Marketplace **classic Kubernetes app**: customers deploy
ASP into their own GKE cluster, and the deployer installs the Helm chart in
`marketplace/chart/asp` (frontend, backend, bundled in-cluster PostgreSQL and Redis).

Producer Portal product (project `codsec-public`): service name
`asp-codsec.endpoints.codsec-public.cloud.goog`. Images live in
`us-docker.pkg.dev/codsec-public/asp-deployer`:

- `asp` - backend (the primary image)
- `asp/frontend` - frontend
- `asp/deployer` - the deployer

## 1. Build and lint

```bash
cd marketplace
make lint                     # helm lint + template
make deployer                 # docker build + push the deployer image (track + version tags)
```

## 2. Annotate every image with the product service name

Marketplace requires a manifest **annotation** (a Dockerfile `LABEL` is not enough) on the
deployer and every application image, pointing at the product's service name:

```bash
SVC=services/asp-codsec.endpoints.codsec-public.cloud.goog
for img in asp asp/frontend asp/deployer; do
  crane mutate "us-docker.pkg.dev/codsec-public/asp-deployer/$img:1.0" \
    --annotation "com.googleapis.cloudmarketplace.product.service.name=$SVC"
done
```

The durable fix is `docker buildx build --annotation ...` in the image pipelines
(`mcp-project` for the backend, `chat-ui-mcp-project` for the frontend).

## 3. Verify

```bash
mpdev verify --deployer=us-docker.pkg.dev/codsec-public/asp-deployer/asp/deployer:1.0
```

Run against a throwaway GKE cluster. Marketplace validation installs and uninstalls the
deployer, so a green `mpdev verify` is the best pre-submit signal.

## 4. Producer Portal

1. Container images -> Deployer image URL
   `us-docker.pkg.dev/codsec-public/asp-deployer/asp/deployer` -> Specify Releases.
2. New Release: Display Tag `1.0`, Version title `1.0`. Fill the public git repo URL (this
   repo) and the deploy documentation URL (`docs/install.md`). Submit the Container Images
   review early - it can take two or more weeks.
3. Product details: set a Support URL or contact (`support@codsec.io`) and submit the
   Product details review.

> Marketplace snapshots a release immutably per Display Tag plus Version. If you change an
> image, that produces a new digest (re-annotate it) and needs a new release; re-pushing
> the same tag does not refresh a release that was already submitted.
