# Publishing the ASP Terraform Kubernetes app to Cloud Marketplace

This module is the Marketplace **Terraform Kubernetes app**: it provisions GKE
Autopilot + managed Cloud SQL (Postgres 16) and deploys the app Helm chart
(backend, frontend, in-cluster Redis) via the Helm provider.

## Key fact: how Marketplace validates this path
For a Terraform Kubernetes app, Marketplace's release validation is that the
**module runs `terraform plan` successfully** — it does **not** run a full
install + health check at release time (unlike the classic deployer `mpdev
verify`). So the old worry about the backend `/api/health` passing against a
live DB is **not** a release-validation blocker here.

## Artifacts and where they live
| Artifact | Location | Status |
|----------|----------|--------|
| backend / frontend images | `us-docker.pkg.dev/codsec-public/asp-deployer/asp` and `.../asp/frontend`, tags `1.0` + `1.0.0`, service-name label | ✅ pushed |
| Helm chart (OCI) | Artifact Registry, see "Push the chart" | ⬜ |
| Terraform module (this dir) | ZIP in a **versioned** GCS bucket in `codsec-public` | ⬜ |
| `metadata.yaml` + `metadata.display.yaml` | generated into this dir by `cft` | ⬜ |

## 1. Push the Helm chart to Artifact Registry (OCI)
`helm push` names the artifact after the chart's `name:` (which is `asp`). The
backend image already occupies `.../asp-deployer/asp`, so pushing the chart into
the same repo would collide on the `asp` path. Use a **separate chart repo** to
avoid that:

```bash
gcloud artifacts repositories create asp-charts \
  --repository-format=docker --location=us --project=codsec-public   # one-time

helm package marketplace/chart/asp            # -> asp-1.0.0.tgz
helm push asp-1.0.0.tgz oci://us-docker.pkg.dev/codsec-public/asp-charts
# chart now at: us-docker.pkg.dev/codsec-public/asp-charts/asp:1.0.0
```
Then set `chart_oci_ref = "oci://us-docker.pkg.dev/codsec-public/asp-charts/asp"`
in the module (variables.tf default) so `helm_release` pulls it.

> Portal "Helm chart URL" format is `us-docker.pkg.dev/PROJECT/PRODUCT/CHART_NAME`
> → `us-docker.pkg.dev/codsec-public/asp-charts/asp`.

## 2. Generate the UI metadata (CFT)
```bash
cft blueprint metadata -p terraform-marketplace -q -d --nested=false   # writes metadata.yaml + metadata.display.yaml
cft blueprint metadata -p terraform-marketplace -v                     # validate
```
(Install `cft` from the Cloud Foundation Toolkit CLI.)

## 3. Package the module + upload to a versioned GCS bucket
```bash
gsutil mb -p codsec-public -l us gs://codsec-asp-tf-module    # one-time
gsutil versioning set on gs://codsec-asp-tf-module            # REQUIRED: versioning on

(cd terraform-marketplace && zip -r ../asp-tf-module-1.0.0.zip . -x '.terraform/*' '*.tfstate*')
gsutil cp asp-tf-module-1.0.0.zip gs://codsec-asp-tf-module/
```

## 4. Producer Portal — Deployment configuration
- Product type: **Terraform Kubernetes app**
- **Helm chart URL:** `us-docker.pkg.dev/codsec-public/asp-charts/asp`
- **Release:** display tag `1.0` (matches the chart tag), version title e.g. `1.0.0`
- **Terraform module:** the `gs://codsec-asp-tf-module/asp-tf-module-1.0.0.zip` URI
- **Map the image variable** so the billing entitlement binds (backend = primary)
- Marketplace then runs `terraform plan` to validate the release.

## Open items needing Portal-assigned values
- `partnerId` / `solutionId` must match the listing IDs in the Portal — confirm
  them and reconcile the AR repo/paths if they differ from `codsec-public/asp-*`.
- Pricing model (BYOL/free vs usage-based). Usage-based adds a `product.metadata`
  annotation in the chart `deployment.yaml` and `serviceLevel: default` in values.
