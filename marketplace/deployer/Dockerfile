# Marketplace classic Kubernetes app deployer (Helm based), onbuild variant.
#
# The onbuild base packages the chart from the build context into
# /data/chart/chart.tar.gz (the layout the deployer runtime actually reads) and
# runs envsubst on schema.yaml. The onbuild does `mv chart.tmp/* chart`, so the
# build context's chart/ must hold EXACTLY ONE chart subdirectory (Chart.yaml at
# chart/asp/Chart.yaml), with schema.yaml alongside chart/ - the Makefile builds
# with the marketplace/ directory as the context.

# kubectl and helm are rebuilt from upstream source rather than taken from the
# base or a release download: no released binary is built with go >= 1.26.9 and
# golang.org/x/net >= 0.60.0, which the Marketplace scan requires. Rebuilding
# the same tag with a current toolchain and the patched module clears both.
# Drop these stages once upstream releases meet those minimums.
ARG GO_IMAGE=golang:1.26.9-bookworm
ARG XNET_VERSION=v0.60.0

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS helm-build
ARG HELM_VERSION=v4.2.4
ARG XNET_VERSION
RUN git clone --quiet --depth 1 --branch ${HELM_VERSION} \
      https://github.com/helm/helm.git /src
WORKDIR /src
RUN go get golang.org/x/net@${XNET_VERSION} oras.land/oras-go/v2@v2.6.2 \
    && go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 make build \
    && go version -m bin/helm | grep -E 'go1|x/net'

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS kubectl-build
ARG KUBECTL_VERSION=v1.37.1
ARG XNET_VERSION
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends rsync jq
RUN git clone --quiet --depth 1 --branch ${KUBECTL_VERSION} \
      https://github.com/kubernetes/kubernetes.git /src
WORKDIR /src
RUN hack/pin-dependency.sh golang.org/x/net ${XNET_VERSION} && hack/update-vendor.sh
RUN KUBE_GIT_VERSION=${KUBECTL_VERSION} KUBE_GIT_TREE_STATE=clean \
    KUBE_BUILD_PLATFORMS=linux/amd64 make WHAT=cmd/kubectl \
    && go version -m _output/local/bin/linux/amd64/kubectl | grep -E 'go1|x/net'

FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild

RUN apt-get update -qq \
    && apt-get install -y -qq --only-upgrade libssl3 openssl \
    && rm -rf /var/lib/apt/lists/*

# The base ships one kubectl per supported minor under /opt/kubectl/v*/; all
# of them are replaced with the rebuilt binary.
COPY --from=kubectl-build /src/_output/local/bin/linux/amd64/kubectl /tmp/kubectl
RUN set -eux; \
    for d in /opt/kubectl/v*/; do install -m 755 /tmp/kubectl "$d/kubectl"; done; \
    rm /tmp/kubectl; \
    /opt/kubectl/default/kubectl version --client

COPY --from=helm-build /src/bin/helm /usr/local/bin/helm
RUN helm version

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
