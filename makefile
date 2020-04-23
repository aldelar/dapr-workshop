DOCKER_IMAGE_PREFIX ?=
APPS                ?=loan-predictor

REGISTRY 		    ?=daprworkshopacr.azurecr.io/daprworkshop
REL_VERSION         ?=latest

# Add latest tag if LATEST_RELEASE is true
LATEST_RELEASE ?=

# Docker image build and push setting
DOCKER:=docker
DOCKERFILE:=Dockerfile

.PHONY: build
SAMPLE_APPS:=$(foreach ITEM,$(APPS),$(DOCKER_IMAGE_PREFIX)$(ITEM))
build: $(SAMPLE_APPS)

# Generate docker image build targets
# Params:
# $(1): app name
# $(2): tag name
define genDockerImageBuild
.PHONY: $(DOCKER_IMAGE_PREFIX)$(1)
$(DOCKER_IMAGE_PREFIX)$(1):
	$(DOCKER) build -f $(1)/$(DOCKERFILE) $(1)/. -t $(REGISTRY)/$(DOCKER_IMAGE_PREFIX)$(1):$(2)
endef

# Generate docker image build targets
$(foreach ITEM,$(APPS),$(eval $(call genDockerImageBuild,$(ITEM),$(REL_VERSION))))

# push docker image to the registry
.PHONY: push
PUSH_SAMPLE_APPS:=$(foreach ITEM,$(APPS),push-$(DOCKER_IMAGE_PREFIX)$(ITEM))
push: $(PUSH_SAMPLE_APPS)

# Generate docker image push targets
# Params:
# $(1): app name
# $(2): tag name
define genDockerImagePush
.PHONY: push-$(DOCKER_IMAGE_PREFIX)$(1)
push-$(DOCKER_IMAGE_PREFIX)$(1):
	$(DOCKER) push $(REGISTRY)/$(DOCKER_IMAGE_PREFIX)$(1):$(2)
ifeq ($(LATEST_RELEASE),true)
	$(DOCKER) tag $(REGISTRY)/$(DOCKER_IMAGE_PREFIX)$(1):$(2) $(REGISTRY)/$(DOCKER_IMAGE_PREFIX)$(1):latest
	$(DOCKER) push $(REGISTRY)/$(DOCKER_IMAGE_PREFIX)$(1):latest
endif
endef

# Generate docker image push targets
$(foreach ITEM,$(APPS),$(eval $(call genDockerImagePush,$(ITEM),$(REL_VERSION))))

# Deploy all components and services
.PHONY: deploy
deploy: deploy-components deploy-apps
deploy-components:
	kubectl apply -f ./components
deploy-apps:
	kubectl apply -f ./deploy

# Undeploy all components and services
.PHONY: undeploy
undeploy: undeploy-components undeploy-apps
undeploy-components:
	kubectl delete -f ./components
undeploy-apps:
	kubectl delete -f ./deploy

# Run market-data-provider service
.PHONY: run
run: run-loan-predictor
run-loan-predictor:
	dapr run --app-id loan-predictor run-loan-predictor.bat