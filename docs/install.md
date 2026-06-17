# Install

The recommended path is the **Google Cloud Marketplace** listing: deploy from the ASP
product page, choose your cluster and namespace, set the domain and admin email, and
Marketplace mirrors the images into your project and runs the deployer.

These steps cover the **command-line** alternative, installing the same Helm chart
directly into an existing GKE cluster.

## 1. Connect to your cluster

```bash
gcloud container clusters get-credentials CLUSTER_NAME \
  --location LOCATION --project PROJECT_ID
```

## 2. Install

The chart deploys the frontend and backend, connects them to the PostgreSQL and Redis you
provide, runs the database migrations, and creates your first admin user automatically.

Set your domain, admin email, and the connection details for your PostgreSQL 16 database
and Redis (see [prerequisites](prerequisites.md)). The admin password is the login you'll
use - it must be at least 12 characters with an upper case letter, a lower case letter, a
digit, and a symbol. The JWT secret and admin API key can be generated on the spot. A
Google API key is optional: without it the app installs and you can log in, but the chat
agent won't respond.

```bash
git clone https://github.com/CodSecIO/Codsec-asp-marketplace-envs
cd Codsec-asp-marketplace-envs

helm install asp marketplace/chart/asp \
  --namespace asp --create-namespace \
  --set domain=asp.example.com \
  --set adminEmail=admin@yourcompany.com \
  --set adminPassword='ChooseAStr0ng!Password' \
  --set googleApiKey=YOUR_GOOGLE_API_KEY \
  --set db.host=YOUR_PG_HOST --set db.port=5432 \
  --set db.user=asp --set db.name=asp \
  --set db.password='YOUR_PG_PASSWORD' \
  --set redis.host=YOUR_REDIS_HOST --set redis.port=6379 \
  --set jwtSecret="$(openssl rand -hex 24)" \
  --set apiKey="$(openssl rand -hex 24)"
```

> Redis with a password or TLS: add `--set redis.password='...'` and/or
> `--set redis.tls=true`. The backend connects to PostgreSQL without TLS, so the database
> must accept non-TLS connections.

> The default images live in a private Artifact Registry. Make sure your GKE nodes can
> pull them: Marketplace handles this automatically, and for a direct install you can
> request access from CodSec or override `backend.image.repo` / `frontend.image.repo`.

> To front ASP with your own ingress or load balancer, add `--set ingress.enabled=false`
> and skip steps 3-4 (DNS + managed certificate).

## 3. Point DNS at the load balancer

```bash
kubectl -n asp get ingress asp -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Create an A record for your domain pointing at that IP.

## 4. Wait for the certificate

The GKE managed certificate is issued once your domain resolves to the load balancer;
first provisioning can take up to an hour.

```bash
kubectl -n asp get managedcertificate asp-cert -o jsonpath='{.status.certificateStatus}'
```

## 5. Log in

Open `https://asp.example.com` and sign in with the `adminEmail` / `adminPassword` you
set at install. To check the backend directly:

```bash
kubectl -n asp get pods
curl https://asp.example.com/api/health
```
