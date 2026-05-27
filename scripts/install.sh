#!/usr/bin/env bash
set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${REGION:=us-central1}"
: "${DOMAIN:?DOMAIN must be set (e.g. asp.example.com)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Terraform apply"
cd "$ROOT/terraform"
[[ -f terraform.tfvars ]] || {
  echo "terraform.tfvars missing. Copy examples/terraform.tfvars.example and edit it."
  exit 1
}
terraform init -upgrade
terraform apply -auto-approve \
  -var "project_id=$PROJECT_ID" \
  -var "region=$REGION"

CLUSTER=$(terraform output -raw cluster_name)
LOCATION=$(terraform output -raw cluster_location)
cd "$ROOT"

echo "==> Fetching kubeconfig"
gcloud container clusters get-credentials "$CLUSTER" \
  --region "$LOCATION" --project "$PROJECT_ID"

kubectl get namespace asp >/dev/null 2>&1 || kubectl create namespace asp

if ! kubectl -n asp get secret asp-backend-env >/dev/null 2>&1; then
  cat <<EOF
Secret 'asp-backend-env' not found in namespace 'asp'.
Create it with your DATABASE_URL / REDIS_URL / JWT_SECRET (see docs/install.md),
then re-run this script or run the helm commands manually.
EOF
  exit 1
fi

echo "==> Helm install backend"
helm upgrade --install asp-backend "$ROOT/helm/backend" \
  --namespace asp \
  --set ingress.host="api.$DOMAIN"

echo "==> Helm install frontend"
helm upgrade --install asp-frontend "$ROOT/helm/frontend" \
  --namespace asp \
  --set ingress.host="$DOMAIN" \
  --set backend.url="https://api.$DOMAIN"

echo "==> Install complete."
echo "    Point DNS for $DOMAIN and api.$DOMAIN at the gateway_ip output."
