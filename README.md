# dapr-workshop

workshop using [dapr](https://dapr.io) (Distributed Application Runtime) as a distributed micro-services framework

This workshop sets up a dapr environment to build micro services deployed in a Kubernetes cluster. We'll use a machine learning model as the core of a mini web service deployed in aks with dapr, and leveraging a state store.

The deployment will setup:
- Azure Container Registry
- Azure Kunernetes Services with Advanced Networking (for direct vnet access from pods)
- Azure Identity
- Azure Key Vault (secret store)
- Azure Cosmos DB (state store)

The application code will be based on python, but dapr is language agnostic so the concepts can be reused with any language.

prx: a prefix of your own to avoid URI conflicts. For instance: 3 letters based on your firstname, middlename, lastname ignitials.

# Setup Azure Services

## Create a resource group (RG)

    name:   dapr-workshop

## Create an Azure Kubernetes Service (AKS)

    name:   prxdaprworkshopaks

Enabled Advanced Networking and setup your vnet and dns:

VNET:

    name:   daprworkshopvnet

DNS:

    name:   daprworkshopdns

## Create an Azure Key Vault (AKV)

    name:   prxdaprworkshopakv

On the networking pane, select 'Public endpoint (selected networks)' and then select the VNET created while creating AKS, and the 'default' subnet. Click Create to create an endpoint. Once the endpoint is created, click 'Add'.

Keep the rest of the defaults.

## Create an Azure Container Registry (ACR)

    name:   prxdaprworkshopacr
    Admin:  enabled

## Register ACR with AKS

    az aks update -n prxdaprworkshopaks -g dapr-workshop --attach-acr prxdaprworkshopacr

# Setup Local Development Environment

## Install Miniconda

[Miniconda](https://docs.conda.io/en/latest/miniconda.html)

## Install Scoop

suggested:

    iwr -useb get.scoop.sh | iex

## Install dapr

[dapr](https://dapr.io/)

## Install Docker Desktop

[Docker Desktop](https://www.docker.com/products/docker-desktops)

## Authenticate Docker against Azure Container Registry

Go to the Azure Container Registry in the Azure portal, click on 'Access Keys' and enable the 'Admin User'. You will find there a username and two passwords you can use with the command below to authenticate Docker against ACR.

    docker login prxdaprworkshopacr --username _username_ --password _password_

## Install Kubectl

[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Install Helm 3.1

[helm](https://helm.sh/docs/intro/install/)

suggested:

    scoop install helm=3.1.0

## Install Make

suggested:

    scoop install make

## Register AKS with Kubectl

    az aks get-credentials --resource-group dapr-workshop --name prxdaprworkshopaks

## Setup Azure Key Vault

[Setup Secret Store for Azure Key Vault](https://github.com/dapr/docs/blob/master/howto/setup-secret-store/azure-keyvault.md)

## Install Dapr in Kubernetes

[Using Helm](https://github.com/dapr/docs/blob/master/getting-started/environment-setup.md#using-helm-advanced)

## Authenticate ACR with Docker

    az acr login --name prxdaprworkshopacr
