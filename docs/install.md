# Install

The recommended path is the **Google Cloud Marketplace** listing: deploy from the ASP
product page, choose your cluster and namespace, set the domain, and Marketplace mirrors
the images into your project and runs the deployer.

These steps cover the **command-line** alternative, installing the same Helm chart
directly into an existing GKE cluster.

## 1. Connect to your cluster

```bash
gcloud container clusters get-credentials CLUSTER_NAME \
  --location LOCATION --project PROJECT_ID
```

## 2. Install

The chart deploys the frontend and backend, bundles Redis 8 in-cluster, connects to the
PostgreSQL you provide, and runs the database migrations. It does **not** create an admin
user - the first admin signs in via SAML SSO (see step 5).

Set your domain and the connection details for your PostgreSQL 16 database
(see [prerequisites](prerequisites.md)). The JWT secret and bootstrap key can be generated
on the spot. A Google API key is optional: without it the app installs and you can log in,
but the chat agent won't respond.

```bash
git clone https://github.com/CodSecIO/Codsec-asp-marketplace-envs
cd Codsec-asp-marketplace-envs

helm install asp marketplace/chart/asp \
  --namespace asp --create-namespace \
  --set domain=asp.example.com \
  --set googleApiKey=YOUR_GOOGLE_API_KEY \
  --set db.host=YOUR_PG_HOST --set db.port=5432 \
  --set db.user=asp --set db.name=asp \
  --set db.password='YOUR_PG_PASSWORD' \
  --set jwtSecret="$(openssl rand -hex 24)" \
  --set apiKey="$(openssl rand -hex 24)" \
  --set bootstrapApiKey="$(openssl rand -hex 24)"
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

## 5. First admin (SAML SSO)

ASP has no local email/password admin - the first `MASTER_TENANT_ADMIN` is created by the
first SAML SSO login. Once the app is up, seed the master-tenant SAML config once, using
the `bootstrapApiKey` you set (the backend exposes it as `BOOTSTRAP_API_KEY`):

```bash
BKEY=<the bootstrapApiKey you set>
curl -X POST "https://<domain>/api/settings/bootstrap" \
  -H "Authorization: $BKEY" -H "Content-Type: application/json" \
  -d '{
    "idp_entity_id": "<your IdP entity ID>",
    "idp_sso_url":   "<your IdP SSO URL>",
    "idp_slo_url":   "<your IdP logout URL>",
    "idp_x509_cert": "<your IdP signing certificate>",
    "sp_entity_id":  "<the SP entity ID for the master-tenant app>"
  }'
```

Then open `https://<domain>` and sign in through your IdP - the first master-tenant login
is provisioned as the admin. The endpoint refuses once an admin already exists.

> For SSO to complete, the backend's SAML SP settings must be configured for your IdP:
> `SAML_SP_URL`, `SAML_SP_X509CERT`, `SAML_SP_PRIVATEKEY`, `FRONTEND_URL`, and
> `ALLOWED_REDIRECT_ORIGINS`. Set them on the `asp-backend` deployment. Turnkey SAML
> wiring in the chart is a planned follow-up.

```bash
kubectl -n asp get pods
```
