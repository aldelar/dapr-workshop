APPS                ?=loan-predictor
REGISTRY_PREFIX		?=daprworkshopacr
REGISTRY 		    ?=.azurecr.io/daprworkshop
REL_VERSION         ?=latest

# Add latest tag if LATEST_RELEASE is true
LATEST_RELEASE ?=

# Docker image build and push setting
DOCKER:=docker
DOCKERFILE:=Dockerfile

# App Port
APP_PORT:=808

.PHONY: build
SAMPLE_APPS:=$(foreach ITEM,$(APPS),$(DOCKER_IMAGE_PREFIX)$(REGISTRY_PREFIX)$(ITEM))
build: $(SAMPLE_APPS)

# Generate docker image build targets
# Params:
# $(1): app name
# $(2): tag name
define genDockerImageBuild
.PHONY: $(DOCKER_IMAGE_PREFIX)$(REGISTRY_PREFIX)$(1)
$(DOCKER_IMAGE_PREFIX)$(REGISTRY_PREFIX)$(1):
	$(DOCKER) build -f $(1)/$(DOCKERFILE) $(1)/. -t $(REGISTRY_PREFIX)$(REGISTRY)/$(DOCKER_IMAGE_PREFIX)$(1):$(2)
endef

# Generate docker image build targets
$(foreach ITEM,$(APPS),$(eval $(call genDockerImageBuild,$(ITEM),$(REL_VERSION))))

# push docker image to the registry
.PHONY: push
PUSH_SAMPLE_APPS:=$(foreach ITEM,$(APPS),push-$(DOCKER_IMAGE_PREFIX)$(REGISTRY_PREFIX)$(ITEM))
push: $(PUSH_SAMPLE_APPS)

# Generate docker image push targets
# Params:
# $(1): app name
# $(2): tag name
define genDockerImagePush
.PHONY: push-$(DOCKER_IMAGE_PREFIX)$(REGISTRY_PREFIX)$(1)
push-$(DOCKER_IMAGE_PREFIX)$(REGISTRY_PREFIX)$(1):
	$(DOCKER) push $(REGISTRY_PREFIX)$(REGISTRY)/$(DOCKER_IMAGE_PREFIX)$(1):$(2)
ifeq ($(LATEST_RELEASE),true)
	$(DOCKER) tag $(REGISTRY_PREFIX)$(REGISTRY)/$(DOCKER_IMAGE_PREFIX)$(1):$(2) $(REGISTRY_PREFIX)$(REGISTRY)/$(DOCKER_IMAGE_PREFIX)$(1):latest
	$(DOCKER) push $(REGISTRY_PREFIX)$(REGISTRY)/$(DOCKER_IMAGE_PREFIX)$(1):latest
endif
endef

# Generate docker image push targets
$(foreach ITEM,$(APPS),$(eval $(call genDockerImagePush,$(ITEM),$(REL_VERSION))))

# Deploy all components and services
.PHONY: deploy
deploy: deploy-components deploy-apps
deploy-components:
	kubectl apply -f ./components$(COMPONENTS_SUFFIX)
deploy-apps:
	kubectl apply -f ./deploy$(COMPONENTS_SUFFIX)

# Undeploy all components and services
.PHONY: undeploy
undeploy: undeploy-components undeploy-apps
undeploy-components:
	kubectl delete -f ./components$(COMPONENTS_SUFFIX) --ignore-not-found=true
undeploy-apps:
	kubectl delete -f ./deploy$(COMPONENTS_SUFFIX) --ignore-not-found=true

# set APP_POD_NAME
set-app-pod-name:
	$(eval APP_POD_NAME := $(shell kubectl get po --selector=app=loan-predictor -o jsonpath='{.items[*].metadata.name}'))

# Port forward
.PHONY: port-forward
port-forward: set-app-pod-name port-forward-loan-predictor
port-forward-loan-predictor:
	kubectl port-forward $(APP_POD_NAME) $(APP_PORT):$(APP_PORT)

# Logs: TODO, make this multi apps
.PHONY:  dapr-logs
dapr-logs: set-app-pod-name get-dapr-logs
get-dapr-logs:
	kubectl logs $(APP_POD_NAME) daprd -f

# Logs: TODO, make this multi apps
.PHONY: app-logs
app-logs: set-app-pod-name get-app-logs
get-app-logs:
	kubectl logs $(APP_POD_NAME) market-data-provider -f

## BUILD TARGETS
use-context:
	kubectl config use-context $(CLUSTER)
	kubectl config get-contexts
# set PROD
.PHONY: use-prod
use-prod: set-prod-env use-context
set-prod-env:
	$(eval DOCKER_IMAGE_PREFIX:= )
	$(eval REGISTRY_PREFIX := daprworkshopacr)
	$(eval COMPONENTS_SUFFIX := -prod)
	$(eval CLUSTER := daprworkshopaks)

# DEV: Run market-data-provider service in local standalone dev mode
.PHONY: dev
dev: run-loan-predictor
run-loan-predictor:
	dapr run --app-id loan-predictor --app-port 808 run-loan-predictor.bat

# PRODUCTION: Build and redeploy to k8s
.PHONY: prod
prod: set-prod-env use-context re-build-deploy

#
re-build-deploy: build push undeploy deploy