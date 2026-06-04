# Build and test the ASP Marketplace deployer.
# Requires: docker, helm, and mpdev (github.com/GoogleCloudPlatform/marketplace-k8s-app-tools).

REGISTRY ?= us-docker.pkg.dev/codsec-public/asp-deployer
APP      ?= asp
TRACK    ?= 1.0
VERSION  ?= 1.0.0

DEPLOYER := $(REGISTRY)/$(APP)/deployer

.PHONY: lint deployer verify

# helm lint + render the chart locally with default values (no Marketplace substitution).
lint:
	helm lint chart/asp
	helm template asp chart/asp >/dev/null && echo "template OK"

# Build and push the deployer image. The onbuild base packages chart/ + schema.yaml;
# REGISTRY/TAG are passed for the base image's schema envsubst step. Build context
# is this directory (it holds chart/ and schema.yaml).
# NOTE: each service image (chat-ui, secops-agent) must also carry the
# annotation com.googleapis.cloudmarketplace.product.service.name=services/<name>
# before submission; that is done where those images are built, not here.
deployer:
	# --platform=linux/amd64: Marketplace runs images on x86 nodes; a Mac (arm64)
	# build is rejected. --provenance=false: emit a plain single-arch image, not
	# an OCI index with an attestation manifest (which breaks schema extraction).
	docker build \
	  --platform=linux/amd64 --provenance=false \
	  --build-arg REGISTRY=$(REGISTRY) --build-arg TAG=$(VERSION) \
	  -t $(DEPLOYER):$(TRACK) -t $(DEPLOYER):$(VERSION) \
	  -f deployer/Dockerfile .
	docker push $(DEPLOYER):$(TRACK)
	docker push $(DEPLOYER):$(VERSION)

# Install + verify against the current kube context (a throwaway test cluster).
verify:
	mpdev verify --deployer=$(DEPLOYER):$(TRACK)
