# Marketplace classic Kubernetes app deployer (Helm based), onbuild variant.
#
# The onbuild base packages the chart from the build context into
# /data/chart/chart.tar.gz (the layout the deployer runtime actually reads) and
# runs envsubst on schema.yaml. The chart must live at `chart/` in the build
# context (Chart.yaml at chart/Chart.yaml) with schema.yaml alongside it - the
# Makefile builds with the marketplace/ directory as the context.
#
# NOTE: the produced image must still pass `mpdev verify` on a test GKE cluster
# before submission (see README open items).
FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild
