#usr/bin/bash

#задача 3:

export RESOURCE_GROUP_NAME=workload-rg
export LOCATION=francecentral
export VM_NAME=VM1
export VM_IMAGE=UbuntuLTS
export VM_NAME2=VM2

export VNET_NAME=virtual_network
export VNET_SUBNET_NAME=default

export RESOURCE_GROUP_NAME2=infra-service-rg
export BASTION_SUBNET_NAME=AzureBastionSubnet
export BASTION_LOCATION=northeurope

export BASTION_PUBLIC_IP=BastionIP
export BASTION_NAME=MyBastion
export BASTION_VNET_NAME=bastion_virtual_network

export NSG_NAME=bastion_nsg
export NSG_BASTION_NAME=disable_traffic
export NSG_IN_RULE_NAME=disable_inbound_traffic
export NSG_OUT_RULE_NAME=disable_outbound_traffic

export NSG_RULE_NAME2=allow_ssh
export VNET_PEERING_NAME=workload-infrasrvc-peering
export VNET_PEERING_NAME2=infrasrvc-workload-peering

SSH_KEY=$(awk '{print $2}' ~/.ssh/id_ed25519.pub)

export VNET_ADDRESS_PREFIX='10.0.0.0/16'
export SUBNET_PREFIX='10.0.0.0/24'
export BASTION_ADDRESS_PREFIX='10.3.0.0/16'
export BASTION_SUBNET_PREFIX='10.3.0.0/24'


VM_USER=$(awk '{print}' /home/bobi/Documents/Bosch/Zadacha3_Credentials/VM_USER)
VM_PASS=$(awk '{print}' /home/bobi/Documents/Bosch/Zadacha3_Credentials/VM_PASS)

#export VM_USER="bobi"
#export VM_PASS="@Azurepass123"

# 1. Create a resource group called "workload-rg"

az group create \
  -l $LOCATION \
  -n $RESOURCE_GROUP_NAME

#2.1 Deploy a VNET (don't forget the subnet!!)

# az network vnet create --address-prefixes 10.0.0.0/16 --name MyVirtualNetwork --resource-group test-rg  --subnet-name MyAseSubnet --subnet-prefixes 10.0.0.0/24

az network vnet create \
  --address-prefixes $VNET_ADDRESS_PREFIX \
  -n $VNET_NAME \
  -g $RESOURCE_GROUP_NAME \
  --subnet-name $VNET_SUBNET_NAME \
  --subnet-prefixes $SUBNET_PREFIX

#2.2 Create 2 VM's with private IP's only and assign them to the VNET!

az vm create \
  -n $VM_NAME \
  -g $RESOURCE_GROUP_NAME \
  --public-ip-address "" \
  --image $VM_IMAGE \
  --vnet-name $VNET_NAME \
  --subnet $VNET_SUBNET_NAME \
  --ssh-key-values $SSH_KEY \
  --admin-username $VM_USER \
  --admin-password $VM_PASS

az vm create \
  -n $VM_NAME2 \
  -g $RESOURCE_GROUP_NAME \
  --public-ip-address "" \
  --image $VM_IMAGE \
  --vnet-name $VNET_NAME \
  --subnet $VNET_SUBNET_NAME \
  --ssh-key-values $SSH_KEY \
  --admin-username $VM_USER \
  --admin-password $VM_PASS


#3.1 Create another resource group called "infra-service-rg"

az group create \
  -l $LOCATION \
  -n $RESOURCE_GROUP_NAME2

#3.2 Deploy a Vnet and Bastion host in it
#3.2.1 Create a virtual network and an Azure Bastion subnet

az network vnet create \
  --address-prefixes $BASTION_ADDRESS_PREFIX \
  -n $BASTION_VNET_NAME \
  -g $RESOURCE_GROUP_NAME2 \
  --subnet-name $BASTION_SUBNET_NAME \
  --subnet-prefixes $BASTION_SUBNET_PREFIX \
  --location $BASTION_LOCATION \
  

#3.2.2 Create a public IP address for Azure Bastion
az network public-ip create \
  --resource-group $RESOURCE_GROUP_NAME2 \
  --name $BASTION_PUBLIC_IP \
  --sku Standard \
  --location $BASTION_LOCATION

#3.2.3 Create a new Azure Bastion resource in the AzureBastionSubnet of your virtual network. It takes about 10 minutes for the Bastion resource to create and deploy
az network bastion create \
  --name $BASTION_NAME \
  --public-ip-address $BASTION_PUBLIC_IP \
  --resource-group $RESOURCE_GROUP_NAME2 \
  --vnet-name $BASTION_VNET_NAME \
  --location $BASTION_LOCATION

#4. Use an NSG to disable any traffic other from bastion host subnet

#4.1 Creating a network security group
az network nsg create \
  --resource-group $RESOURCE_GROUP_NAME2 \
  --name $NSG_NAME


#4.2 Create a rule to disable any traffic other from bastion host subnet [NOT FINISHED!!]
#a) Deny any Inbound traffic from the internet to the VNET
#b) Deny any Outbound traffic from the VNET to the Internet

az network nsg rule create \
  --resource-group $RESOURCE_GROUP_NAME2 \
  --nsg-name $NSG_NAME \
  --name $NSG_IN_RULE_NAME \
  --access Deny \
  --protocol "*" \
  --direction Inbound \
  --priority 110 \
  --source-address-prefix "Internet" \
  --source-port-range "*" \
  --destination-address-prefix "VirtualNetwork" \
  --destination-port-range "*" 


az network nsg rule create \
  --resource-group $RESOURCE_GROUP_NAME2 \
  --nsg-name $NSG_NAME \
  --name $NSG_OUT_RULE_NAME \
  --access Deny \
  --protocol "*" \
  --direction Outbound \
  --priority 110 \
  --source-address-prefix "VirtualNetwork" \
  --source-port-range "*" \
  --destination-address-prefix "Internet" \
  --destination-port-range "*" 

 
#5. Enable SSH connection via Bastion host toward any of the VMs from #2.

#--> CONNECT FROM LOCAL MACHINE TO VM2[INSIDE "workload-rg"] THROUGH BASTION HOST [INSIDE "infra-service-rg"] 
# Solution: through vnet peering --?
#To successfully peer two virtual networks this command must be called twice with the values for --vnet-name and --remote-vnet reversed.

net1Id=$(az network vnet show \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $VNET_NAME \
  --query id --out tsv)

net2Id=$(az network vnet show \
  --resource-group $RESOURCE_GROUP_NAME2 \
  --name $BASTION_VNET_NAME \
  --query id --out tsv)


az network vnet peering create \
  -g $RESOURCE_GROUP_NAME \
  -n $VNET_PEERING_NAME \
  --vnet-name $VNET_NAME \
  --remote-vnet $net2Id \
  --allow-vnet-access

az network vnet peering create \
  -g $RESOURCE_GROUP_NAME2 \
  -n $VNET_PEERING_NAME2 \
  --vnet-name $BASTION_VNET_NAME \
  --remote-vnet $net1Id \
  --allow-vnet-access