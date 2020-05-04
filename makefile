# Define apps and registry
APPS                ?=loan-predictor
REGISTRY 		    ?=.azurecr.io/daprworkshop
REL_VERSION         ?=latest

# Docker image build and push setting
DOCKER:=docker
DOCKERFILE:=Dockerfile

# App Port
APP_PORT:=808

# buildAppImage
# Params:
# $(1): app name
# $(2): tag name
# $(3): registry prefix
define buildAppImage
	$(DOCKER) build -f $(1)/$(DOCKERFILE) $(1)/. -t $(3)$(REGISTRY)/$(1):$(2)
endef
.PHONY: build
build:
	$(foreach APP,$(APPS),$(call buildAppImage,$(APP),$(REL_VERSION),$(REGISTRY_PREFIX)))

# pushAppImage
# Params:
# $(1): app name
# $(2): tag name
# $(3): registry prefix
define pushAppImage
	$(DOCKER) push $(3)$(REGISTRY)/$(1):$(2)
endef
.PHONY: push
push:
	$(foreach APP,$(APPS),$(call pushAppImage,$(APP),$(REL_VERSION),$(REGISTRY_PREFIX)))

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
# $(app): app name passed from command line
set-app-pod-name:
	$(eval APP_POD_NAME := $(shell kubectl get po --selector=app=$(app) -o jsonpath='{.items[*].metadata.name}'))

# Logs
# $(app): app name passed from command line
.PHONY:  dapr-logs
dapr-logs: set-app-pod-name get-dapr-logs
get-dapr-logs:
	kubectl logs $(APP_POD_NAME) daprd -f

# App Logs:
# $(app): app name passed from command line
.PHONY: app-logs
app-logs: set-app-pod-name get-app-logs
get-app-logs:
	kubectl logs $(APP_POD_NAME) $(app) -f

# Port forward
# $(app): app name passed from command line
.PHONY: port-forward
port-forward: set-app-pod-name port-forward-app
port-forward-app:
	kubectl port-forward $(APP_POD_NAME) $(APP_PORT):$(APP_PORT)

## use CLUSTER
use-context:
	kubectl config use-context $(CLUSTER)
	kubectl config get-contexts
# set QA
.PHONY: use-qa
use-qa: set-qa-env use-context
set-qa-env:
	$(eval CLUSTER := daprworkshopqaaks)
	$(eval REGISTRY_PREFIX := daprworkshopaksqaacr)
	$(eval COMPONENTS_SUFFIX := -qa)
# set PROD
.PHONY: use-prod
use-prod: set-prod-env use-context
set-prod-env:
	$(eval CLUSTER := daprworkshopaks)
	$(eval REGISTRY_PREFIX := daprworkshopacr)
	$(eval COMPONENTS_SUFFIX := -prod)

#
.PHONY: re-build-deploy
re-build-deploy: build push undeploy deploy

# runApp
# Params:
# $(1): app name
define runApp
	dapr run --app-id $(1) --app-port 808 run-$(1).bat
endef
#
# DEV: Run apps services in local standalone dev mode (Docker Desktop)
#
.PHONY: dev
dev:
	$(foreach APP,$(APPS),$(call runApp,$(APP)))

#
# QA: Build and redeploy to k8s-qa
#
.PHONY: qa
qa: use-qa re-build-deploy

#
# PRODUCTION: Build and redeploy to k8s
#
.PHONY: prod
prod: use-prod re-build-deploy