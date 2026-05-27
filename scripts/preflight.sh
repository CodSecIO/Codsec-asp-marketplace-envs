#!/usr/bin/env bash
set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${REGION:=us-central1}"

echo "==> Project: $PROJECT_ID  Region: $REGION"

for bin in gcloud kubectl helm terraform; do
  command -v "$bin" >/dev/null || { echo "missing: $bin"; exit 1; }
done

gcloud auth print-access-token >/dev/null || {
  echo "Run: gcloud auth login && gcloud auth application-default login"
  exit 1
}

gcloud config set project "$PROJECT_ID" >/dev/null

echo "==> Enabling required APIs"
gcloud services enable \
  container.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  compute.googleapis.com \
  servicenetworking.googleapis.com \
  iam.googleapis.com \
  --project "$PROJECT_ID"

echo "==> Preflight OK"
