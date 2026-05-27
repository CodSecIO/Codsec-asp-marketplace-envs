# Install

## 1. Configure

```bash
export PROJECT_ID=your-gcp-project
export REGION=us-central1
export DOMAIN=asp.example.com
```

## 2. Preflight

```bash
./scripts/preflight.sh
```

Verifies `gcloud` auth, enables required APIs, and checks quotas.

## 3. Provision infrastructure

```bash
cd terraform
cp examples/terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
terraform init
terraform apply
cd ..
```

Outputs:
- `cluster_name` — GKE cluster
- `db_connection_name` — CloudSQL instance
- `redis_host` — Memorystore endpoint
- `gateway_ip` — static IP for DNS

## 4. Connect kubectl

```bash
gcloud container clusters get-credentials "$(terraform -chdir=terraform output -raw cluster_name)" \
  --region "$REGION" --project "$PROJECT_ID"
```

## 5. Create the backend secret

The backend reads its configuration from a Kubernetes Secret you create yourself. The repo never ships secret values.

```bash
kubectl create namespace asp
kubectl -n asp create secret generic asp-backend-env \
  --from-literal=DATABASE_URL='postgresql+psycopg://USER:PASS@HOST/DB' \
  --from-literal=REDIS_URL='redis://HOST:6379/0' \
  --from-literal=JWT_SECRET='<random 32+ chars>'
```

Add any additional environment variables your subscription requires.

## 6. Deploy applications

```bash
helm upgrade --install asp-backend ./helm/backend \
  --namespace asp \
  --set image.repository=YOUR_IMAGE_REPO/asp-backend \
  --set image.tag=YOUR_VERSION \
  --set ingress.host="api.$DOMAIN"

helm upgrade --install asp-frontend ./helm/frontend \
  --namespace asp \
  --set image.repository=YOUR_IMAGE_REPO/asp-frontend \
  --set image.tag=YOUR_VERSION \
  --set ingress.host="$DOMAIN" \
  --set backend.url="https://api.$DOMAIN"
```

## 7. DNS

Point `$DOMAIN` and `api.$DOMAIN` at the `gateway_ip` from step 3.

## 8. Verify

```bash
kubectl -n asp get pods
curl https://api.$DOMAIN/healthz
```

Open `https://$DOMAIN` in a browser.
