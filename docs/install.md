# Install

The recommended path is the **Google Cloud Marketplace** listing: deploy from the ASP
product page, choose your cluster and namespace, set the two domains and your SAML IdP
details, and Marketplace mirrors the images into your project and runs the deployer. Filling
the IdP fields makes the first-admin SSO set itself up automatically (see step 5).

These steps cover the **command-line** alternative, installing the same Helm chart
directly into an existing GKE cluster.

## 1. Connect to your cluster

```bash
gcloud container clusters get-credentials CLUSTER_NAME \
  --location LOCATION --project PROJECT_ID
```

## 2. Install

The chart deploys the chat frontend, the backend, the admin **backoffice** console, bundles
Redis 8 in-cluster, connects to the PostgreSQL you provide, and runs the database
migrations. It does **not** create an admin user - the first admin signs in via SAML SSO,
which the chart wires up for you (see step 5).

Set two hostnames:

- `domain` - the chat UI and backend `/api` (e.g. `asp.example.com`).
- `backofficeDomain` - the master-admin backoffice console (e.g. `admin.example.com`).

Also set the connection details for your PostgreSQL 16 database
(see [prerequisites](prerequisites.md)) and your SAML IdP details so the first-admin SSO is
configured on install. The JWT secret and bootstrap key can be generated on the spot. A
Google API key is optional: without it the app installs and you can log in, but the chat
agent won't respond.

```bash
git clone https://github.com/CodSecIO/Codsec-asp-marketplace-envs
cd Codsec-asp-marketplace-envs

helm install asp marketplace/chart/asp \
  --namespace asp --create-namespace \
  --set domain=asp.example.com \
  --set backofficeDomain=admin.example.com \
  --set googleApiKey=YOUR_GOOGLE_API_KEY \
  --set db.host=YOUR_PG_HOST --set db.port=5432 \
  --set db.user=asp --set db.name=asp \
  --set db.password='YOUR_PG_PASSWORD' \
  --set jwtSecret="$(openssl rand -hex 24)" \
  --set apiKey="$(openssl rand -hex 24)" \
  --set bootstrapApiKey="$(openssl rand -hex 24)" \
  --set saml.idpEntityId='YOUR_IDP_ENTITY_ID' \
  --set saml.idpSsoUrl='YOUR_IDP_SSO_URL' \
  --set-file saml.idpX509Cert=idp-signing-cert.pem
```

> The IdP signing certificate is a multi-line PEM, so pass it with `--set-file` (reads the
> file into the value) rather than `--set`. In the Marketplace form you paste it directly.

> **SAML fields are optional.** Leave `saml.idpEntityId` / `saml.idpSsoUrl` /
> `saml.idpX509Cert` blank and the app still installs, but the first admin isn't set up -
> you then seed the SAML config manually (see step 5). Fill them and a post-install Job
> seeds the master-tenant SAML config for you.

> **Your IdP must release three attributes** on the SAML assertion: the user's email, first
> name, and last name. The app looks for them under the names `email`, `first-name`, and
> `last-name` by default. If your IdP uses different attribute names, override them (e.g. an
> IdP that sends `firstName` / `lastName`):
> ```bash
>   --set saml.attrEmail=email \
>   --set saml.attrFirstName=firstName \
>   --set saml.attrLastName=lastName
> ```

> Redis 8 is bundled in-cluster (it ships the RedisJSON + RediSearch modules the agent
> needs), so there is nothing to provide. The backend connects to PostgreSQL without TLS,
> so the database must accept non-TLS connections.

> The default images live in a private Artifact Registry. Make sure your GKE nodes can
> pull them: Marketplace handles this automatically, and for a direct install you can
> request access from CodSec or override `backend.image.repo` / `frontend.image.repo` /
> `backoffice.image.repo`.

> **By default ASP has no public ingress** - the Services are ClusterIP, so you front them
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
`/api`) on the `domain` hostname, and `asp-backoffice` (port 80, path `/`) on the
`backofficeDomain` hostname, with your own ingress/load balancer and TLS.

## 4. Bundled ingress only (`--set ingress.enabled=true`)

The bundled ingress serves **both** hostnames off one load balancer, and the managed
certificate covers both. Point DNS for `domain` **and** `backofficeDomain` at the load
balancer IP, then wait for the managed certificate (first provisioning can take up to an
hour):

```bash
kubectl -n asp get ingress asp -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# create an A record for BOTH domain and backofficeDomain -> that IP
kubectl -n asp get managedcertificate asp-cert -o jsonpath='{.status.certificateStatus}'
```

## 5. First admin (turnkey SAML SSO)

ASP has no local email/password admin - the first `MASTER_TENANT_ADMIN` is created by the
first SAML SSO login. When you provide the `saml.idp*` fields at install (step 2), the chart
generates the SP keypair, wires the backend's SAML settings, and runs a post-install Job
that seeds the master-tenant SAML config for you. **No manual bootstrap call is needed.**

Register ASP as a SAML service provider (SP) at your IdP, so the IdP will accept the login:

- **SP entity ID:** `https://<domain>/saml/master`
- **ACS (assertion consumer service) URL:** `https://<domain>/api/auth/saml/callback`

Then, once the app is up and the certificate is `Active`, open `https://<backofficeDomain>`
and sign in through your IdP - the first master-tenant login is provisioned as the master
admin. The bootstrap Job refuses once an admin already exists, so re-running the deploy is
safe.

```bash
kubectl -n asp get pods
```

> **Manual bootstrap (only if you left the `saml.idp*` fields blank).** Seed the
> master-tenant SAML config once, using the `bootstrapApiKey` you set (the backend exposes
> it as `BOOTSTRAP_API_KEY`):
> ```bash
> BKEY=<the bootstrapApiKey you set>
> curl -X POST "https://<domain>/api/settings/bootstrap" \
>   -H "Authorization: $BKEY" -H "Content-Type: application/json" \
>   -d '{
>     "idp_entity_id": "<your IdP entity ID>",
>     "idp_sso_url":   "<your IdP SSO URL>",
>     "idp_slo_url":   "<your IdP logout URL>",
>     "idp_x509_cert": "<your IdP signing certificate>",
>     "sp_entity_id":  "https://<domain>/saml/master"
>   }'
> ```

> **Upgrade caveat.** A version upgrade **may regenerate the SAML SP keypair** (persistence
> across upgrade is not yet verified). If it does, the SP metadata your IdP has on file goes
> stale, so after an upgrade you may need to re-register the SP metadata (entity ID + ACS
> above, with the new SP certificate) at your IdP before SSO works again.
