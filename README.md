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
    region: (something close to you, make sure you pick this region moving forward for all other services to be created)

## Create an Azure Kubernetes Service (AKS)

    name:       prxdaprworkshopaks
    version:    1.16.7 (or highest version in GA)
    node size:  B2s (smallest size possible for a workshop)
    node count: 1 (only for testing, recommendation is 3 minimum)

Networking pane: Enable Advanced Networking and setup your vnet and dns:

VNET:

    name:   daprworkshopvnet

DNS:

    name:   daprworkshopdns

Integrations pane: click create new on Log Analytics workspace

    name:   daprworkshopla

## Create an Azure Key Vault (AKV)

    name:   prxdaprworkshopakv

On the networking pane, select 'Public endpoint (selected networks)' and then select the VNET created while creating AKS, and the 'default' subnet. Click Create to create an endpoint. Once the endpoint is created, click 'Add'.

Keep the rest of the defaults.

## Create an Azure Container Registry (ACR)

    name:   prxdaprworkshopacr
    Admin:  enabled
    SKU:    Basic

## Register ACR with AKS

    az aks update -n prxdaprworkshopaks -g dapr-workshop --attach-acr prxdaprworkshopacr

# Setup Local Development Environment

## Install Miniconda

[Miniconda](https://docs.conda.io/en/latest/miniconda.html)

## Install Scoop (if using Windows)

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

    # installation with Helm 3.x
    helm repo add dapr https://daprio.azurecr.io/helm/v1/repo
    helm repo update
    kubectl create namespace dapr-system
    helm install dapr dapr/dapr --namespace dapr-system
    
    # check that it is running
    kubectl get pods -n dapr-system

## Install Redis in Kubernetes

Redis is necessary to enable a pubsub messaging system and the actor model with DAPR (cross apps communications). If you prefer to point to an existing instance of redis you can use, skip the installation of redis in kubernetes. Nevertheless, for this workshop, this is the simplest way to get up and running with a kubernetes hosted redis instance

     # installation with Helm 3.x
     helm repo add bitnami https://charts.bitnami.com/bitnami
     helm repo update
     helm install redis bitnami/redis

    # check that it is running
    kubectl get pods

Now, let's grab the auto generated password and store it in AKV for later use in DAPR components configurations.

WINDOWS:

    # gets the encoded password
    kubectl get secret --namespace default redis -o jsonpath="{.data.redis-password}" > password.encoded.b64

    # decode the password
    certutil -decode password.encoded.b64 password.txt

    # get the password and copy it into your clipboard
    cat password.txt

Linux/Mac:

    # gets the password and copy it into your clipboard
    kubectl get secret --namespace default redis -o jsonpath="{.data.redis-password}" | base64 --decode

Now, go to AKV in the Azure portal.
Let's configure the firewall to enable you to manage the KeyVault from your desktop.
Go to https://www.whatsmyip.org/ and copy your external IP address.
Click on Networking in AKV and add this IP address into the Firewall IPv4 field, then click 'Save'.

Click on 'Secrets' and create a new secret:

    secret name:    redisPassword
    secret value:   (paste the password from the password retrieval steps above)

We will use AKV to store all secrets that relate to your 'production' environment (AKS in Azure for this workshop).

The best practice would be to setup another AKV instance for developement to completely prevent issues of sharing resources between these environments. For the sake of simplicity for this workshop, the same AKV instance will be used by 'dev' and 'prod' but the process to be followed below to setup 'prod' can just be applied for any other environment ('qa', etc.) and the AKV part can be replicated to leverage a standalone dev AKV instance for the dev environment (the only Azure component we will use in Azure for 'dev').

WINDOWS: delete the password.encoded.b64 and password.txt from your filesytem now that it is saved in AKV

## Authenticate ACR with Docker

Go to ACR and copy one of the passwords for the Admin user, then run this command:

    docker login prxdaprworkshopacr.azurecr.io -u prxdaprworkshopacr -p <password>


# SETUP the DAPR project

We'll start with the production ('-prod' folders) in the project to configure the components and applications to point to your Azure services.

## deploy-prod folder

This folder contains the definitions of all your applications. Here we just have one named 'load-predictor' which is a python based application leveraging FastAPI to create a mini web service app.

Edit the loan-predictor.yaml file to set the 'image' field to point to the Docker image we'll be building and pushing to our registry:

    "image": prxdaprworkshopacr.azurecr.io/daprworkshop/loan-predictor:latest

## components-prod folder

This folder contains the definition of all the dapr components used for this workshop.

pubsub.yaml and statestore.yaml are fundational in a sense that they are necessary to support a full featured dapr platform including cross apps communications. We'll boot these ups against the redis components we have installed in our AKS cluster.

We actually have nothing to configure here as they are setup to use the azurekeyvault to lookup the redis password by key (redisPassword).

### azurekeyvault.yaml setup

So let's configure the azurekeyvault.yaml file which is the only component we need to setup to then be able to use AKV keys wherever we need to set sensisitive information in our config files (or access them from our apps).

First replace the following value with your AKV name:

    "vaultname": prxdaprworkshopakv

Now, we'll use a Service Principal (SP) to enable access to the Key Vault, and will store the SP certificate into the AKS cluster itself to secure access.

    # create a service principal (cert will expire after 1 year)
    az ad sp create-for-rbac --name prxdaprworkshopsp --create-cert --cert prxdaprworkshopspcert --keyvault prxdaprworkshopakv --skip-assignment --years 1
    # NOTE: copy the "appId" from the output above as we need it for the next step

    # display details of the SP we just created, using the "appId" from the step above
    az ad sp show --id [appId]
    # NOTE: copy the "objectId" from the output of this command

    # Let's grant the SP permission to access the AKV using the "objectId" from the step above
    az keyvault set-policy --name prxdaprworkshopakv --object-id [objectId] --secret-permissions get

    # Download the certificate
    az keyvault secret download --vault-name prxdaprworkshopakv --name prxdaprworkshopspcert --file prxdaprworkshopspcert.txt

    # Linux/Mac: decode the cert
    base64 --decode prxdaprworkshopspcert.txt > prxdaprworkshopspcert.pfx

    # Windows: decode the cert
    certutil -decode prxdaprworkshopspcert.txt prxdaprworkshopspcert.pfx

Now that we have our certificate file, we'll save it as a secret into our AKS cluster.

    # save certificate as a secret in AKS
    kubectl create secret generic prxdaprworkshopspcert --from-file=prxdaprworkshopspcert.pfx

    # check that the secret has been store
    kubectl get secrets
    # you should see an entry for your new secret, and it should be of type 'Opaque'

You can now delete prxdaprworkshopspcert.txt from your local filesystem BUT
keep prxdaprworkshopspcert.pfx as we'll use this file to run our 'dev' environment and have it use the same AKV instance for secrets.

Now that our certificate is setup, let's complete the configuration of azurekeyvault.yaml:

    # retrieve your "tenantId" and "appId" from the steps above (if you lost that information, go to (*) below to retrieve them)

Update the yaml file fields:

    "tenantId":     <your tenant id>
    "clientId:      <your app id>

(*) Retrieving details about a Service Principal:
- go to the Azure Portal, click on All Services, and find Azure Active Directory
- click on 'App Registrations'
- type 'dapr' in the search box, the service principal name you created should come back in that list
- click on it, and retrieve the 'Application (client) ID' and the 'Directory (tenant) ID'

You're all set. The DAPR secret store component of type Azure Key Vault is now configured to leverage your AKV instance, by authenticating with the certificate uploaded as a secret in your AKS cluster.

### AKV setup for Dev

As discussed above, we will have the 'dev' environment leverage the same Azure Key Vault. Since there's no kubernetes cluster for the dev environment (aka 'standalone' dapr environment), there's only a slight change in the configuration where we'll indicate that the certificate is coming from a local file and not Kubernetes.

Copy the tenantID and clientID values from your prod yaml file into the dev version of this file (the one under 'components'), and make sure the pfx file name matches the name of your local file.

Make sure the .pfx file is at the root level of the workshop project folder.

## applications folders, one per app

### loan-predictor

The conda.yaml file is here for you to create the environment necessary to run this app locally which we'll get to later on ('dev' mode).

Nothing to configure here as this is very generic.

# Running the application locally (dev mode)

    make dev

This will launch dapr into Docker Desktop, it will automatically create local redis services, deploy an AKV component and authenticate it using your local .pfx file, and then deploy all apps under 'deploy'.

If all goes well you should be able to go to your web browser:

    http://localhost:808

Verify that it outputs 'loan-predictor'.

# Deploying the application to production

    make prod

This will:

    1) build a container image for your app(s)
    2) push them to your AKV
    3) deploy all components to AKS
    4) deploy all apps to AKS

Once completed, you can leverage the following helpers:

    make dapr-logs
    # display the full dapr boot logs to see if any service had any issue.

    make app-logs
    # display the app logs

    make port-forward
    # forwards the AKS app port to a local proxy port so you can test your app within your web browser or via curl

Note that these makefile targets have just been built to simplify testing this workshop and are not part of the dapr best practices. Feel free to adjust how you want to go about releasing this code to your environments using your traditional DevOps pipelines. This is purely to help you understand what it takes to deploy a dapr based set of applications into Kubernetes and how to develop these locally via Docker.