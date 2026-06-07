# ASP - Google Cloud Marketplace Terraform Kubernetes app

Marketplace product where customers deploy ASP through Infrastructure Manager.
This is a **separate product** from the classic deployer in `marketplace/`
(one listing cannot offer both deployment methods); both share the chart at
`marketplace/chart/asp` - this module renders it with `postgres.bundled=false`.

**What the module deploys:** managed Cloud SQL PostgreSQL 16 (private IP,
`deletion_protection` on) + the ASP chart (frontend, backend, in-cluster
Redis). By default onto the customer's **existing** cluster and network
(which must already have Private Services Access); `create_cluster` /
`create_network` are opt-in for greenfield. `modules/` holds vendored copies
of our production modules from `CodSecIO/terraform-modules` (private repo, so
the code ships in the package) - every adjustment is commented in place.

## Releasing a new version (example: 1.2)

One-time tools: `gcloud` (CLI **and** `gcloud auth application-default login`
- the Terraform provider uses ADC), `helm`, the `cft` CLI, and a **Terraform
1.5.7 binary** - that exact version is what Marketplace validation and
customer deploys run.

1. **Change and verify the module** (hard rules: `required_version` must
   allow 1.5.7; no cross-variable `validation` blocks (1.9+ feature); no
   complex variable types - the Deploy Config UI rejects `map(any)` etc.;
   every Marketplace-injected variable keeps a default so a bare plan works;
   `goog_cm_deployment_name` must exist and prefix all resource names):

   ```bash
   cd terraform-marketplace
   cft blueprint metadata -p . -q -d --nested=false   # regen after ANY variable change
   terraform-1.5.7 init -backend=false && terraform-1.5.7 validate
   terraform-1.5.7 plan -var-file=marketplace_test.tfvars -var project_id=<test-project>
   terraform-1.5.7 plan -var project_id=<test-project>   # bare plan must also pass
   ```

2. **Tag the artifacts with the new Display Tag.** Chart and images must
   carry the same MAJOR.MINOR tag, and images live as **siblings of the
   chart, named by the `schema.yaml` keys** (`backend`, `frontend`):

   ```bash
   for a in asp backend frontend; do
     gcloud artifacts docker tags add \
       us-docker.pkg.dev/codsec-public/asp-charts/$a:1.1 \
       us-docker.pkg.dev/codsec-public/asp-charts/$a:1.2
   done
   ```

   If the chart or images actually changed: `helm package` + `helm push`
   (chart), and rebuild images with `--platform=linux/amd64
   --provenance=false`, then add the **manifest annotation** (a Dockerfile
   LABEL is not enough):

   ```bash
   crane mutate --annotation \
     "com.googleapis.cloudmarketplace.product.service.name=services/asp-cloud-codsec.endpoints.codsec-public.cloud.goog" \
     us-docker.pkg.dev/codsec-public/asp-charts/<image>:1.2
   ```

3. **Package the module.** The ZIP must contain `README.md`,
   `metadata.yaml`, `metadata.display.yaml`, `schema.yaml`, and
   `marketplace_test.tfvars`, and must contain **no `.terraform*` entry**
   (the lock file included). Use a **new object name for every revision**:

   ```bash
   zip -r asp-tf-module-1.2.0.zip . -x '.terraform*' '*.tfstate*'
   gcloud storage cp asp-tf-module-1.2.0.zip gs://codsec-asp-tf-module/
   ```

4. **Producer Portal** -> product -> Deployment configuration -> New
   Release: Display Tag `1.2`, Version title `1.2.0`, module = the new ZIP
   (Browse), required roles (Service Usage Admin, Kubernetes Engine Admin,
   Cloud SQL Admin, Compute Network Admin, Service Networking Admin, Secret
   Manager Admin, Service Account Admin, Service Account User, Cloud
   Infrastructure Manager Admin), **Done** -> set Default -> **Save and
   validate**.

5. **Iterating on validation failures.** Marketplace snapshots the package
   per version identity and the snapshot is immutable: every revision needs
   a **new ZIP object name AND a new Version title** (`1.2.1`, `1.2.2`...).
   If the error turns generic/masked ("Terraform plan command failed...
   contact support"), stale failed versions are poisoning the report -
   delete them; if it persists, mint a **fresh Display Tag** (step 2) and
   rebuild the release there. Reproduce plan failures locally with the
   1.5.7 binary, never a newer one.

Validation only runs `terraform plan`. Before publishing a release to
customers, run a real `terraform apply` (both existing-cluster and
greenfield modes) on a throwaway project.
