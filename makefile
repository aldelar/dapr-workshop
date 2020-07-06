# Define apps and registry
APPS      	?=loan-predictor
REGISTRY 	?=.azurecr.io/daprworkshop
REL_VERSION ?=latest

# Target setup
QA_REGISTRY_PREFIX:=daprworkshopaksqaacr
QA_TARGET_PREFIX:=qa
PROD_REGISTRY_PREFIX:=daprworkshopacr
PROD_TARGET_PREFIX:=prod

# Docker image build and push setting
DOCKER:=docker
DOCKERFILE:=Dockerfile

# Params:
# $(1): app name
# $(2): tag name
# $(3): registry prefix
# $(4): target prefix
define genDockerImageBuild
.PHONY: build-$(4)-$(1)
build-$(4)-$(1):
	$(DOCKER) build -f $(1)/$(DOCKERFILE) $(1)/. -t $(3)$(REGISTRY)/$(1):$(2)
endef

# Generate docker image build targets: QA
$(foreach APP,$(APPS),$(eval $(call genDockerImageBuild,$(APP),$(REL_VERSION),$(QA_REGISTRY_PREFIX),$(QA_TARGET_PREFIX))))
# Generate docker image build targets: PROD
$(foreach APP,$(APPS),$(eval $(call genDockerImageBuild,$(APP),$(REL_VERSION),$(PROD_REGISTRY_PREFIX),$(PROD_TARGET_PREFIX))))

# QA: build-qa
.PHONY: build-qa
build-qa: $(foreach APP,$(APPS),build-$(QA_TARGET_PREFIX)-$(APP))

# PROD: build-prod
.PHONY: build-prod
build-prod: $(foreach APP,$(APPS),build-$(PROD_TARGET_PREFIX)-$(APP))

# Generate docker image push targets
# Params:
# $(1): app name
# $(2): tag name
# $(3): registry prefix
# $(4): target prefix
define genDockerImagePush
.PHONY: push-$(4)-$(1)
push-$(4)-$(1):
	$(DOCKER) push $(3)$(REGISTRY)/$(1):$(2)
endef
# Generate docker image push targets: QA
$(foreach APP,$(APPS),$(eval $(call genDockerImagePush,$(APP),$(REL_VERSION),$(QA_REGISTRY_PREFIX),$(QA_TARGET_PREFIX))))
# Generate docker image push targets: PROD
$(foreach APP,$(APPS),$(eval $(call genDockerImagePush,$(APP),$(REL_VERSION),$(PROD_REGISTRY_PREFIX),$(PROD_TARGET_PREFIX))))

# QA: push-qa
.PHONY: push-qa
push-qa: $(foreach APP,$(APPS),push-$(QA_TARGET_PREFIX)-$(APP))

# PROD: push-prod
.PHONY: push-prod
push-prod: $(foreach APP,$(APPS),push-$(PROD_TARGET_PREFIX)-$(APP))

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
	kubectl port-forward $(APP_POD_NAME) $(port):808

## use CLUSTER
.PHONY: use-context
use-context:
	kubectl config use-context $(CLUSTER)
	kubectl config get-contexts
# set QA
.PHONY: use-qa
use-qa: set-qa-env use-context
set-qa-env:
	$(eval CLUSTER := daprworkshopqaaks)
	$(eval COMPONENTS_SUFFIX := -qa)
# set PROD
.PHONY: use-prod
use-prod: set-prod-env use-context
set-prod-env:
	$(eval CLUSTER := daprworkshopaks)
	$(eval COMPONENTS_SUFFIX := -prod)

# runApp
# Params:
# $(1): app name
define runApp
	dapr run --app-id $(1) --app-port $(2) run-$(1).bat
endef
#
# DEV: Run apps services in local standalone dev mode (Docker Desktop)
#
.PHONY: dev
dev:
	$(call runApp,$(app),$(port))

#
# QA: Build and redeploy to k8s-qa
#
.PHONY: qa
qa: use-qa build-qa push-qa undeploy deploy

#
# PRODUCTION: Build and redeploy to k8s
#
.PHONY: prod
prod: use-prod build-prod push-prod undeploy deploy

# Upgrade Services
.PHONE: upgrade-services
upgrade-services:
	helm repo update
	helm upgrade redis bitnami/redis
	helm upgrade dapr dapr/dapr -n dapr-system

#
# Dev: upgrade services
#
.PHONY: upgrade-dev
upgrade-dev:
	powershell -Command "iwr -useb https://raw.githubusercontent.com/dapr/cli/master/install/install.ps1 | iex"
	dapr init --runtime-version latest

#
# QA: upgrade services
#
.PHONY: upgrade-qa
upgrade-qa: use-qa upgrade-services

#
# PRODUCTION: upgrade-services
#
.PHONY: upgrade-prod
upgrade-prod: use-prod upgrade-services