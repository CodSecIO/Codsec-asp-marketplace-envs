# Prerequisites

## Tools

- `gcloud` CLI ≥ 470
- `kubectl` ≥ 1.29
- `helm` ≥ 3.14
- `terraform` ≥ 1.6

## GCP

- A GCP project with billing enabled
- Project owner (or equivalent) IAM on first install
- The following APIs enabled (the preflight script will enable them):
  - `container.googleapis.com`
  - `sqladmin.googleapis.com`
  - `redis.googleapis.com`
  - `compute.googleapis.com`
  - `servicenetworking.googleapis.com`
  - `iam.googleapis.com`

## Quotas (default region)

| Resource | Minimum |
|----------|---------|
| In-use IP addresses | 4 |
| CPUs | 8 |
| Persistent Disk SSD (GB) | 100 |

## DNS

A domain you control, with the ability to add an A record pointing to the load balancer IP produced by Terraform.

## Container images

Frontend and backend image tags will be provided by CodSec. Make sure your GKE nodes can pull them (the included setup uses public Artifact Registry; private registries require an additional `imagePullSecret` — see [install.md](install.md)).
