# Marketplace classic Kubernetes app deployer (Helm based), onbuild variant.
#
# The onbuild base packages the chart from the build context into
# /data/chart/chart.tar.gz (the layout the deployer runtime actually reads) and
# runs envsubst on schema.yaml. The onbuild does `mv chart.tmp/* chart`, so the
# build context's chart/ must hold EXACTLY ONE chart subdirectory (Chart.yaml at
# chart/asp/Chart.yaml), with schema.yaml alongside chart/ - the Makefile builds
# with the marketplace/ directory as the context.
FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild

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
