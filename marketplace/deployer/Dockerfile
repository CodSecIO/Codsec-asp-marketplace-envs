# Marketplace classic Kubernetes app deployer (Helm based).
# The marketplace-k8s-app-tools Makefile normally packages the chart into
# /data/chart/*.tar.gz; for a hand build we copy the chart directory directly.
FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm

COPY chart/asp /data/chart/asp
COPY schema.yaml /data/schema.yaml

# The base image's entrypoint runs the Helm-based install against the target
# namespace and creates the Application resource.
