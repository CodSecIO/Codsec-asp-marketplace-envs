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

## Data services

- **PostgreSQL 16 (bring your own)** - host, port (5432), database name, user, and
  password, reachable from the cluster. The backend connects without TLS, so the database
  must accept non-TLS connections (for example Cloud SQL over private IP). The named user
  needs permission to create the schema (the install runs `alembic upgrade head` against
  an empty database).
- **Redis (bundled - nothing to provision)** - ASP runs Redis 8 in-cluster, because the
  agent requires the RedisJSON + RediSearch modules, which Redis 8 ships in core and no
  managed external Redis (Memorystore, ElastiCache) provides. It is backed by a
  PersistentVolumeClaim (default 50Gi), so the cluster needs a default StorageClass and
  enough disk quota.

## Cluster capacity

The release runs the frontend (2 replicas), the backend (2 replicas), and the bundled
Redis (1 replica, sized for large tenants: up to 8Gi memory + a 50Gi PVC by default). Tune
`redis.resources` / `redis.persistence.size` down for a small evaluation.

## DNS

Only for the bundled ingress (`ingress.enabled=true`): a domain you control, with the
ability to add an A record pointing at the ingress load balancer IP created during install.
With your own ingress/LB you manage DNS and TLS yourself.

## Container images

ASP frontend and backend images come with your Marketplace subscription. For a
command-line install that pulls them directly, contact CodSec at support@codsec.io for
Artifact Registry access.
