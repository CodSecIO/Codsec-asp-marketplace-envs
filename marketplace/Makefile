# Build and test the ASP Marketplace deployer.
# Requires: docker, helm, and mpdev (github.com/GoogleCloudPlatform/marketplace-k8s-app-tools).

REGISTRY ?= us-docker.pkg.dev/codsec-public/asp-deployer
APP      ?= asp
TRACK    ?= 0.10
VERSION  ?= 0.10.0

DEPLOYER := $(REGISTRY)/$(APP)/deployer

.PHONY: lint deployer verify

# helm lint + render the chart locally with default values (no Marketplace substitution).
lint:
	helm lint chart
	helm template asp chart >/dev/null && echo "template OK"

# Build and push the deployer image. The onbuild base packages chart/ + schema.yaml;
# REGISTRY/TAG are passed for the base image's schema envsubst step. Build context
# is this directory (it holds chart/ and schema.yaml).
# NOTE: each service image (chat-ui, secops-agent, secops) must also carry the
# annotation com.googleapis.cloudmarketplace.product.service.name=services/<name>
# before submission; that is done where those images are built, not here.
deployer:
	docker build \
	  --build-arg REGISTRY=$(REGISTRY) --build-arg TAG=$(VERSION) \
	  -t $(DEPLOYER):$(TRACK) -t $(DEPLOYER):$(VERSION) \
	  -f deployer/Dockerfile .
	docker push $(DEPLOYER):$(TRACK)
	docker push $(DEPLOYER):$(VERSION)

# Install + verify against the current kube context (a throwaway test cluster).
verify:
	mpdev verify --deployer=$(DEPLOYER):$(TRACK)
