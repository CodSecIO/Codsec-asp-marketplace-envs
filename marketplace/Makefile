# Build, annotate, and test the ASP Marketplace deployer.
# Requires: docker (with buildx), helm, crane, and mpdev
# (github.com/GoogleCloudPlatform/marketplace-k8s-app-tools).

REGISTRY ?= us-docker.pkg.dev/codsec-public/asp-deployer
APP      ?= asp
TRACK    ?= 1.6
VERSION  ?= 1.6.1
SERVICE  ?= services/asp-codsec.endpoints.codsec-public.cloud.goog

DEPLOYER   := $(REGISTRY)/$(APP)/deployer
ANNOTATION := com.googleapis.cloudmarketplace.product.service.name=$(SERVICE)

.PHONY: lint deployer annotate verify

# helm lint + render the chart with the required inputs (no Marketplace substitution).
lint:
	helm lint chart/asp
	helm template asp chart/asp \
	  --set domain=example.com \
	  --set db.host=db --set db.password=x \
	  --set jwtSecret=x --set apiKey=x --set bootstrapApiKey=b \
	  >/dev/null && echo "template OK"

# Build and push the deployer image. The onbuild base bakes a SNAPSHOT of chart/ +
# schema.yaml into the image, so rebuild after ANY change under chart/ or schema.yaml.
# amd64 single-manifest (--provenance=false) so it runs on GKE nodes and `crane mutate`
# can annotate it. Build context is this directory (it holds chart/ and schema.yaml).
deployer:
	docker buildx build --platform linux/amd64 --provenance=false \
	  --build-arg REGISTRY=$(REGISTRY) --build-arg TAG=$(VERSION) \
	  -t $(DEPLOYER):$(TRACK) -t $(DEPLOYER):$(VERSION) \
	  -f deployer/Dockerfile --push .

# Marketplace requires the product service name as an image MANIFEST ANNOTATION on the
# deployer (a Dockerfile LABEL is not enough). Re-run after every `make deployer`.
# The app images (asp, asp/frontend) carry the same annotation, applied in their own
# build pipelines (mcp-project / chat-ui-mcp-project) via `buildx --annotation`.
annotate:
	crane mutate $(DEPLOYER):$(TRACK) --annotation "$(ANNOTATION)" --label "$(ANNOTATION)"
	crane tag $(DEPLOYER):$(TRACK) $(VERSION)

# Install + verify against the current kube context (a throwaway GKE cluster). The
# apptest overlay supplies headless defaults for the required domain + db inputs.
verify:
	mpdev verify --deployer=$(DEPLOYER):$(TRACK)
