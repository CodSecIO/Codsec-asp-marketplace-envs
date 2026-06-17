# Prerequisites

## Tools

- `gcloud` CLI
- `kubectl`
- `helm` 3.x

## GCP

- A GKE cluster (Standard or Autopilot) you can deploy into
- Permission to create a namespace and workloads in that cluster

The chart uses GKE Ingress (`gce`), a `ManagedCertificate`, and a `FrontendConfig` for
HTTPS; these are available on GKE by default.

## Data services (bring your own)

ASP does not run a database or cache in-cluster. Provision and have ready, reachable from
the cluster:

- **PostgreSQL 16** - host, port (5432), database name, user, and password. The backend
  connects without TLS, so the database must accept non-TLS connections (for example Cloud
  SQL over private IP). The named user needs permission to create the schema (the install
  runs `alembic upgrade head` against an empty database).
- **Redis** - host and port (6379). A password and TLS are optional.

## Cluster capacity

The release runs the frontend (2 replicas) and the backend (2 replicas). A small default
node pool is enough for an evaluation.

## DNS

A domain you control, with the ability to add an A record pointing at the Ingress load
balancer IP created during install.

## Container images

ASP frontend and backend images come with your Marketplace subscription. For a
command-line install that pulls them directly, contact CodSec at support@codsec.io for
Artifact Registry access.
