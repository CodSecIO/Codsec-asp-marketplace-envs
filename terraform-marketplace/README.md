# CodSec ASP

Deploys CodSec ASP from Google Cloud Marketplace via Infrastructure Manager:
the application (chat UI, backend API, and an in-cluster Redis cache) on GKE,
backed by a managed Cloud SQL PostgreSQL 16 instance (private IP, automated
backups and point-in-time recovery, deletion protection enabled).

## Prerequisites

- **None by default**: the deployment is self-contained - it creates a
  dedicated VPC (with Private Services Access) and a GKE cluster, then
  installs the app and the database.
- To deploy onto **existing** infrastructure instead, set
  `create_cluster = false` with `cluster_name`, and `create_network = false`
  with your network/subnetwork names. An existing VPC must already have a
  [Private Services Access](https://cloud.google.com/sql/docs/postgres/configure-private-services-access)
  connection - Cloud SQL with a private IP requires it.
- The deploying user needs: Service Usage Admin, Kubernetes Engine Admin,
  Cloud SQL Admin, Compute Network Admin, Service Networking Admin, Secret
  Manager Admin, Service Account Admin, Service Account User, and Cloud
  Infrastructure Manager Admin.

## Key inputs

| Variable | Purpose | Default |
|---|---|---|
| `domain` | Public domain for the chat UI | `asp.example.com` |
| `create_cluster` | Create a dedicated GKE cluster | `true` |
| `cluster_name` | Existing cluster (when `create_cluster = false`) | `""` |
| `create_network` | Create a dedicated VPC | `true` |
| `network_name` / `subnetwork_name` | Existing VPC and subnet (when `create_network = false`) | `default` |
| `region` / `zone` | Location for created resources | `us-central1` |
| `db_tier` | Cloud SQL machine tier | `db-custom-1-3840` |
| `db_deletion_protection` | Protect the database from deletion | `true` |

## After deployment

1. Find the Ingress IP: `kubectl get ingress -n <namespace>` (the namespace
   is in the deployment outputs and defaults to the deployment name).
2. Point the `domain` DNS A record at that IP. The Google-managed TLS
   certificate provisions automatically once DNS resolves.
3. Database connection details are wired into the app automatically; the
   generated credentials are stored in Secret Manager in your project.

**Deleting the deployment:** the Cloud SQL instance ships with
`deletion_protection = true` - deleting the deployment intentionally fails
until you disable it, so the database and its data are never destroyed by
accident.

Support: https://codsec.io
