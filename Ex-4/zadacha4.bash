#usr/bin/bash

export RESOURCE_GROUP_NAME=stream4-aks-rg
export LOCATION=switzerlandnorth
export AKS_NAME=myAKSCluster
export AKS_NAMESPACE1=azure-namespace-ks1
export AKS_NAMESPACE2=azure-namespace-ks2

SSH_KEY=$(awk '{print $2}' ~/.ssh/id_ed25519.pub)

export VM_RG_NAME=workload-rg
export VM_VNET_NAME=virtual_network
export VM_SUBNET_NAME=default

export VNET_NAME=aks-vnet
export ADDRESS_PREFIX='10.6.0.0/16'
export SUBNET_PREFIX='10.6.0.0/24'

export VNET_PEERING_NAME1=aks-to-workload-peering
export VNET_PEERING_NAME2=workload-to-aks-peering


# 1. Create a resource group called "stream4-aks-rg"

az group create -l $LOCATION -n $RESOURCE_GROUP_NAME

# 2. In stream4-rg create an AKS

az aks create \
	-g $RESOURCE_GROUP_NAME \
	-n $AKS_NAME \
	--network-plugin kubenet \
	--ssh-key-value $SSH_KEY \
	-l $LOCATION \
	--node-count 1 \
	--node-vm-size Standard_DS2_v2


#3. Deploy containers from Kubernetes related excersizes into this cluster each into separate namespace (use script)
#3.1. Connect to the cluster (configure localy)

az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_NAME

#3.2 Create and log into namespace
kubectl create namespace $AKS_NAMESPACE1
kubectl config set-context --current --namespace=$AKS_NAMESPACE1

#3.3 Execute secrets set up
sh secrets/db-csv.sh
sh secrets/gh-credentials.sh

#3.4 Storage configuration
kubectl apply -f volume/persistent-volume.yml
kubectl apply -f volume/persistent-volume-claim.yml

#3.4 Start the pod
kubectl apply -f pod/executor-pod.yml

#4. Deploy a container and make sure you are able to connect to VMs in "workload-rg" via ssh directly without using bastion host

#4.1. Vnet peering 

# SSH via workload-rg vnet, since it is peered to infra-service-rg

#export VM_USER="bobi"
#export VM_PASS="@Azurepass123"

#4.1 Create a vnet with a subnet


az network vnet create \
  --address-prefixes $ADDRESS_PREFIX \
  -n $VNET_NAME \
  -g $RESOURCE_GROUP_NAME \
  --subnet-name default \
  --subnet-prefixes $SUBNET_PREFIX \
  --location $LOCATION

#4.2 Get subnet resource ID for the the existing subnet into which the AKS cluster will be joined:
RESOURCE_ID=$(az network vnet subnet list \
    --resource-group $RESOURCE_GROUP_NAME \
    --vnet-name $VNET_NAME \
    --query "[0].id" --output tsv)

#4.3 Create the aks cluster

az aks create \
        -g $RESOURCE_GROUP_NAME \
        -n myAKSCluster2 \
        --ssh-key-value $SSH_KEY \
        -l $LOCATION \
        --node-count 1 \
        --node-vm-size Standard_DS2_v2 \
        --vnet-subnet-id $RESOURCE_ID \
	      --docker-bridge-address '172.17.0.1/16' \
    	  --dns-service-ip '10.2.0.10' \
    	  --service-cidr '10.2.0.0/24' \
	      --network-plugin azure


#4.3 Create a vnet peering between this network and workload-rg network


net1Id=$(az network vnet show \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $VNET_NAME \
  --query id --out tsv)

net2Id=$(az network vnet show \
  --resource-group $VM_RG_NAME \
  --name $VM_VNET_NAME \
  --query id --out tsv)


az network vnet peering create \
  -g $RESOURCE_GROUP_NAME \
  -n $VNET_NAME \
  --vnet-name $VNET_NAME \
  --remote-vnet $net2Id \
  --allow-vnet-access

az network vnet peering create \
  -g $RESOURCE_GROUP_NAME2 \
  -n $VNET_PEERING_NAME2 \
  --vnet-name $VM_VNET_NAME \
  --remote-vnet $net1Id \
  --allow-vnet-access

#4.4 Run a basic docker container 
docker pull busybox
docker run -it busybox /bin/bash

#4.5 Log inside the container and write the following:

RUN apt-get update && apt-get install -y openssh-server apache2 supervisor
ssh -i ~/.ssh/id_ed25519.pub bobi@10.111.12.123
