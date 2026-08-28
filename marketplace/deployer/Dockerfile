# Marketplace classic Kubernetes app deployer (Helm based), onbuild variant.
#
# The onbuild base packages the chart from the build context into
# /data/chart/chart.tar.gz (the layout the deployer runtime actually reads) and
# runs envsubst on schema.yaml. The onbuild does `mv chart.tmp/* chart`, so the
# build context's chart/ must hold EXACTLY ONE chart subdirectory (Chart.yaml at
# chart/asp/Chart.yaml), with schema.yaml alongside chart/ - the Makefile builds
# with the marketplace/ directory as the context.
FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild

# CVE-2026-39821 (golang.org/x/net punycode) plus the go1.26.5 stdlib advisory.
# The base ships kubectl v1.36 built with x/net v0.49.0 on go1.26.5; both are
# flagged. v1.36.4 fixes x/net but is still built with go1.26.5, so only v1.37.0
# clears both. The base fetches "latest stable" at ITS build time, which predated
# these releases. Replacing the binary here removes the finding without waiting
# for a base rebuild. Drop this layer once the base ships kubectl >= v1.37.0.
ARG KUBECTL_VERSION=v1.37.0
RUN set -eux; \
    for d in /opt/kubectl/v*/; do \
      wget -q -O "$d/kubectl" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"; \
      chmod 755 "$d/kubectl"; \
    done; \
    /opt/kubectl/default/kubectl version --client

# The onbuild base only populates /data. `mpdev verify` reads /data-test: a test
# chart (the tester Pod, annotated marketplace.cloud.google.com/verification:test,
# run after install) and a schema overlay that supplies headless defaults for the
# required inputs (domain, adminEmail) so verification can run non-interactively.
# Tarred the same way the base packages /data/chart (chart/ at the tar root).
COPY apptest/deployer/asp /tmp/test/chart
RUN cd /tmp/test \
    && tar -czf chart.tar.gz chart \
    && mkdir -p /data-test/chart \
    && mv chart.tar.gz /data-test/chart/ \
    && rm -rf /tmp/test
COPY apptest/deployer/schema.yaml /data-test/schema.yaml

# `mpdev verify` waits up to WAIT_FOR_READY_TIMEOUT (default 300s) for the app to
# become ready. ASP's cold start (image pulls + DB migrations + first-user
# bootstrap) needs longer. Verify-only: the normal install (deploy.sh) does not wait.
ENV WAIT_FOR_READY_TIMEOUT=900
