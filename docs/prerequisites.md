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

## Cluster capacity

The release runs the frontend (2 replicas), the backend (2 replicas), and one pod each
for the bundled PostgreSQL and Redis. A small default node pool is enough for an
evaluation.

## DNS

A domain you control, with the ability to add an A record pointing at the Ingress load
balancer IP created during install.

## Container images

ASP frontend and backend images come with your Marketplace subscription. For a
command-line install that pulls them directly, contact CodSec at support@codsec.io for
Artifact Registry access.
