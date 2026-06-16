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

The chart deploys the frontend, backend, and bundled in-cluster PostgreSQL and Redis. Set
your domain; the database password and JWT secret are the only other inputs and can be
generated on the spot. The frontend and backend image references default to the published
CodSec images.

```bash
git clone https://github.com/CodSecIO/Codsec-asp-marketplace-envs
cd Codsec-asp-marketplace-envs

helm install asp marketplace/chart/asp \
  --namespace asp --create-namespace \
  --set domain=asp.example.com \
  --set dbPassword="$(openssl rand -hex 16)" \
  --set jwtSecret="$(openssl rand -hex 24)"
```

> The default images live in a private Artifact Registry. Make sure your GKE nodes can
> pull them: Marketplace handles this automatically, and for a direct install you can
> request access from CodSec or override `backend.image.repo` / `frontend.image.repo`.

## 3. Point DNS at the load balancer

Get the Ingress address and create an A record for your domain:

```bash
kubectl -n asp get ingress asp -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## 4. Wait for the certificate

The GKE managed certificate is issued once your domain resolves to the load balancer;
first provisioning can take up to an hour.

```bash
kubectl -n asp get managedcertificate asp-cert -o jsonpath='{.status.certificateStatus}'
```

## 5. Verify

```bash
kubectl -n asp get pods
curl https://asp.example.com/api/health
```

Then open `https://asp.example.com` in a browser.
