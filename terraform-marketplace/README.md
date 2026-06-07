# ASP - Google Cloud Marketplace Terraform Kubernetes app

Terraform module for the Marketplace **Terraform Kubernetes app** product:
customers deploy ASP through Infrastructure Manager. This is a **separate
Marketplace product** from the classic deployer package in `marketplace/`
(product type is fixed at creation; one listing cannot offer both deployment
methods). Both products share the same chart - this module renders it with
`postgres.bundled=false`.

## What it deploys

- **Always:** managed Cloud SQL PostgreSQL 16 (private IP, backups + PITR,
  `deletion_protection` on by default) and the ASP chart (frontend + backend +
  in-cluster Redis) via `helm_release`.
- **By default it deploys onto EXISTING infrastructure** - the customer's
  cluster (`cluster_name`) and network (`network_name`/`subnetwork_name`),
  matching Google's starter-module pattern. The existing network **must
  already have a Private Services Access connection** (Cloud SQL private IP
  requires it; this module deliberately never creates PSA on an existing
  network, because that peering is shared with other services).
- **Opt-in greenfield:** `create_cluster = true` creates a GKE cluster via the
  vendored gke module; `create_network = true` creates a dedicated VPC with
  GKE secondary ranges and PSA via the vendored vpc module.

## Vendored modules

`modules/` contains copies of our production modules from
`CodSecIO/terraform-modules` (private repo - Infrastructure Manager cannot
fetch it, so the code ships inside this package). Adjustments made to the
copies are commented in place:

- exact google provider pins relaxed (one version must satisfy all modules;
  the root pins `~> 7.12`),
- gke: in-module kubernetes/helm provider configs and cluster-convention
  resources (storage classes, compute classes) removed,
- vpc/cloudsql: upstream registry module versions bumped past their
  `google < 7` cap (network 12.0.0, cloud-router 8.3.0, sql-db 27.2.0);
  the cloudsql auth-proxy VM submodule removed.

## Local checks

```bash
terraform fmt -recursive
terraform init -backend=false
terraform validate
```

Marketplace release validation runs `terraform plan --var-file
marketplace_test.tfvars` only - a clean plan does not prove a working deploy.
Run a real `terraform apply` + `helm test`-level smoke check on a throwaway
project before submission.

## Publish

1. Push the chart as an OCI artifact (registry MUST be `us-docker.pkg.dev`):
   ```bash
   helm package ../marketplace/chart/asp        # asp-<version>.tgz
   helm push asp-<version>.tgz oci://us-docker.pkg.dev/codsec-public/asp-charts
   ```
2. Generate UI metadata with the CFT CLI (writes `metadata.yaml` +
   `metadata.display.yaml` into this directory):
   ```bash
   cft blueprint metadata -p . -q -d --nested=false
   cft blueprint metadata -p . -v
   ```
3. ZIP this directory (exclude `.terraform*` - the validator rejects ANY
   `.terraform*` entry, including `.terraform.lock.hcl` - and `*.tfstate*`)
   and upload to a **versioned** GCS bucket in `codsec-public`.
   **Package revision rules (learned from validation rounds):** Marketplace
   snapshots the package per release **version identity** (Display Tag +
   Version title) and the snapshot is immutable - re-selecting the same GCS
   path, re-uploading, or deleting and recreating the release does NOT
   refresh it. For every package revision: upload under a **new object name**
   (`asp-tf-module-X.Y.Z-N.zip`) AND give the release a **new Version title**.
   Validation runs Terraform **1.5.7** (`terraform plan --var-file
   marketplace_test.tfvars`); reproduce failures locally with that exact
   binary - generic plan errors are debuggable only that way.
4. Producer Portal: product type **Terraform Kubernetes app**; Helm chart URL
   format `us-docker.pkg.dev/PROJECT/PRODUCT/CHART_NAME`; attach the module
   ZIP URI; map the image variables from `schema.yaml` so the entitlement
   binds to the backend (primary) image.
