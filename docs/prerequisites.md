# Prerequisites

## Tools

- `gcloud` CLI
- `kubectl`
- `helm` 3.x

## GCP

- A GKE cluster (Standard or Autopilot) you can deploy into
- Permission to create a namespace and workloads in that cluster

By default ASP is exposed as a ClusterIP Service (no public ingress). If you opt into the
bundled ingress (`ingress.enabled=true`), the chart uses GKE Ingress (`gce`), a
`ManagedCertificate`, and a `FrontendConfig` for HTTPS; these are available on GKE by
default.

## Data services (bring your own)

ASP does not run a database or cache in-cluster. Provision and have ready, reachable from
the cluster:

- **PostgreSQL 16** - host, port (5432), database name, user, and password. The backend
  connects without TLS, so the database must accept non-TLS connections (for example Cloud
  SQL over private IP). The named user needs permission to create the schema (the install
  runs `alembic upgrade head` against an empty database).
- **Redis** - host and port (6379); a password and TLS are optional. For **persistent,
  multi-replica agent state**, Redis must provide the **RedisJSON + RediSearch** modules
  (Redis Stack, Redis Enterprise / Redis Cloud, or self-managed Redis with the modules).
  A plain managed Redis without them (for example Cloud Memorystore) still works - the app
  detects the missing modules and falls back to an in-memory checkpointer - but agent
  conversation state is then ephemeral and per-pod (lost on restart, not shared across the
  backend replicas).

## Cluster capacity

The release runs the frontend (2 replicas) and the backend (2 replicas). A small default
node pool is enough for an evaluation.

## DNS

Only for the bundled ingress (`ingress.enabled=true`): a domain you control, with the
ability to add an A record pointing at the ingress load balancer IP created during install.
With your own ingress/LB you manage DNS and TLS yourself.

## Container images

ASP frontend and backend images come with your Marketplace subscription. For a
command-line install that pulls them directly, contact CodSec at support@codsec.io for
Artifact Registry access.
