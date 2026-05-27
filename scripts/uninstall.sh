#!/usr/bin/env bash
set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${REGION:=us-central1}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

helm -n asp uninstall asp-frontend || true
helm -n asp uninstall asp-backend  || true
kubectl delete namespace asp --ignore-not-found

cd "$ROOT/terraform"
terraform destroy -auto-approve \
  -var "project_id=$PROJECT_ID" \
  -var "region=$REGION"

echo "==> Uninstall complete."
