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

The chart deploys the frontend and backend, bundles Redis 8 in-cluster, connects to the
PostgreSQL you provide, runs the database migrations, and creates your first admin user
automatically.

Set your domain, admin email, and the connection details for your PostgreSQL 16 database
(see [prerequisites](prerequisites.md)). The admin password is the login you'll
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
  --set jwtSecret="$(openssl rand -hex 24)" \
  --set apiKey="$(openssl rand -hex 24)"
```

> Redis 8 is bundled in-cluster (it ships the RedisJSON + RediSearch modules the agent
> needs), so there is nothing to provide. The backend connects to PostgreSQL without TLS,
> so the database must accept non-TLS connections.

> The default images live in a private Artifact Registry. Make sure your GKE nodes can
> pull them: Marketplace handles this automatically, and for a direct install you can
> request access from CodSec or override `backend.image.repo` / `frontend.image.repo`.

> **By default ASP has no public ingress** - it is a ClusterIP Service, so you front it
> with your own ingress/load balancer (step 3) or port-forward for a quick look. To use
> the bundled GKE Ingress + managed TLS certificate instead, add `--set ingress.enabled=true`
> and follow step 4.

## 3. Access ASP (default: ClusterIP)

For a quick look, port-forward the frontend:

```bash
kubectl -n asp port-forward svc/asp-frontend 8080:80
# open http://localhost:8080
```

> The frontend's browser calls the backend at the `domain` you set (`https://<domain>/api`),
> so a port-forward shows the UI but **login only works once `domain` resolves to ASP** -
> via your own ingress/load balancer or the bundled ingress.

For real use, front `asp-frontend` (port 80, path `/`) and `asp-backend` (port 80, path
`/api`) with your own ingress/load balancer and TLS, on the hostname you passed as `domain`.

## 4. Bundled ingress only (`--set ingress.enabled=true`)

Point DNS at the load balancer, then wait for the managed certificate (first provisioning
can take up to an hour):

```bash
kubectl -n asp get ingress asp -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# create an A record for your domain -> that IP
kubectl -n asp get managedcertificate asp-cert -o jsonpath='{.status.certificateStatus}'
```

## 5. Log in

Sign in through your access URL (the port-forward, your own ingress, or `https://<domain>`
if you enabled the bundled ingress) with the `adminEmail` / `adminPassword` you set at
install.

```bash
kubectl -n asp get pods
```
