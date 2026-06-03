# Marketplace classic Kubernetes app deployer (Helm based), onbuild variant.
#
# The onbuild base packages the chart from the build context into
# /data/chart/chart.tar.gz (the layout the deployer runtime actually reads) and
# runs envsubst on schema.yaml. The onbuild does `mv chart.tmp/* chart`, so the
# build context's chart/ must hold EXACTLY ONE chart subdirectory (Chart.yaml at
# chart/asp/Chart.yaml), with schema.yaml alongside chart/ - the Makefile builds
# with the marketplace/ directory as the context.
#
# NOTE: the produced image must still pass `mpdev verify` on a test GKE cluster
# before submission (see README open items).
FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild
