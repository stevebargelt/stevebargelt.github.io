---
layout: post
title: 'Automated Build System Part 1.5: Revisiting Part 1 using the Azure CLI'
subtitle: 
portfolio:  
thumbimage: '/assets/azure_docker_jenkins_small.png'
image: '/assets/azure_docker_jenkins.png'
author: Steve Bargelt
category: devops
tags: [jenkins, cd, ci, docker, azure, registry, docker hub, azurecli]
excerpt_separator: <!--more-->
---

### Introduction
Welcome back to my Automated Build System series of tutorials. In part one of this series we used the Azure Portal web interface to setup a Linux VM in Azure, installed Docker on that VM and setup secure communication to the remote Docker host. In this tutorial we will do the same thing but through the Azure command line interface. I'm calling this part 1.5 since this is just another way to accomplish what we did in part one. If you are happy with using the Azure portal then you can skip right to Part 2.

<!--more-->

{% include abs.md %}

This blog post and related video will be short on commentary since the principles from Part one apply. This is just a quick and easy way to get Docker up and running in a VM in Azure without touching the Azure Portal web interface. 

The video tutorial for Part 1.5:
<iframe width="560" height="315" src="https://www.youtube.com/embed/wFDuW1TQBbY" frameborder="0" allowfullscreen></iframe>
<br/>

>Note that in this series I assume you’re on a computer similar to mine (a Macbook running MacOS). It's certainly not a requirement to do this stuff though. You could be on Linux or Windows as a client, though some of the client-side tooling changes around a bit. I'm confident that you will figure it out!

### Azure CLI
You can [install the Azure CLI](https://azure.microsoft.com/en-us/documentation/articles/xplat-cli-install/) locally or if you run Docker on your machine (and I suspect you do if you are interested in this series) running the CLI in a Docker container is my favorite way to access the CLI - nothing installed on my machine!

It is as simple as:

~~~~

docker run -it microsoft/azure-cli

~~~~

### Create SSH Keys 
First we are going to create a place for our public/private server and client certificates to live:

~~~~

mkdir absSetup
cd absSetup
mkdir keys certs

~~~~

And then generate our SSH keypair:

~~~~

ssh-keygen -t rsa -b 2048 -C dockeruser@Azure-dockerBuild -f ./keys/id_dockerBuild_rsa -q -N ''

~~~~

Next we will startup the AzureCLI docker container linking our current directory to the /config folder in the container so we have access to the certs and keys.

~~~~

docker run -td --name azureCli -v /Users/steve/code/absSetup:/config microsoft/azure-cli

~~~~

From here on we will use `docker exec` to execute all of our azure cli commands in our running container.

We must login to the Azure CLI. This is nifty, similar to when you authorize a video device like an Xbox One with a provider such as HBO.  

~~~~

docker exec -it azureCli azure login

~~~~
After we follow the instructions we are logged in and we can procedd to use the azure cli. I have two Azure subscriptions, so I want to make sure I am using the correct one:

~~~~

docker exec -it azureCli azure account set 'Visual Studio Enterprise'

~~~~

### Create the resource group

~~~~

docker exec -it azureCli azure group create dockerBuild westus

~~~~

### Create the virtual network (vnet)

~~~~

docker exec -it azureCli azure network vnet create --resource-group dockerBuild \
    --name dockerBuildvnet \
    --address-prefixes 10.0.0.0/16 \
    --location westus

~~~~

### Create the subnet

~~~~

docker exec -it azureCli azure network vnet subnet create \
    --resource-group dockerBuild \
    --vnet-name dockerBuildvnet \
    --name internal \
	--address-prefix 10.0.0.0/24

~~~~

### Create the IP address

~~~~

docker exec -it azureCli azure network public-ip create --resource-group dockerBuild \
    --name dockerbuild-ip \
    --location westus \
    --allocation-method Static \
    --domain-name-label dockerbuildsystem \
	--idle-timeout 4 \
	--ip-version IPv4

~~~~

### Create the NIC

~~~~

docker exec -it azureCli azure network nic create --name dockerbuildNIC \
    --resource-group dockerBuild \
    --location westus \
    --private-ip-address 10.0.0.4 \
	--subnet-vnet-name dockerBuildvnet \
    --public-ip-name dockerBuild-ip \
	--subnet-name internal

~~~~

### Create the Network Security Group (NSG)

~~~~

docker exec -it azureCli azure network nsg create \
    --resource-group dockerBuild \
    --name dockerBuild-nsg \
    --location westus

~~~~

### Create the inbound security rules

~~~~

docker exec -it azureCli azure network nsg rule create \
    --protocol tcp \
    --direction inbound \
    --priority 1000 \
    --destination-port-range 22 \
    --access allow \
    --resource-group dockerBuild \
    --nsg-name dockerBuild-nsg \
    --name allow-ssh

docker exec -it azureCli azure network nsg rule create \
    --protocol tcp \
    --direction inbound \
    --priority 1010 \
    --destination-port-range 80 \
    --access allow \
    --resource-group dockerBuild \
    --nsg-name dockerBuild-nsg \
    --name allow-http

docker exec -it azureCli azure network nsg rule create \
    --protocol tcp \
    --direction inbound \
    --priority 1020 \
    --destination-port-range 2376 \
    --access allow \
    --resource-group dockerBuild \
    --nsg-name dockerBuild-nsg \
    --name allow-docker-tls

~~~~

### Bind the NSG to the NIC

~~~~

docker exec -it azureCli azure network nic set \
    --resource-group dockerBuild \
    --name dockerbuildNIC \
    --network-security-group-name dockerBuild-nsg

~~~~

### Create the VM

~~~~

docker exec -it azureCli azure vm create \
    --resource-group dockerBuild \
    --name dockerBuild \
    --location westus \
    --vm-size Standard_DS1_V2 \
    --vnet-name dockerBuildvnet \
    --vnet-address-prefix 10.0.0.0/16 \
    --vnet-subnet-name internal \
    --vnet-subnet-address-prefix 10.0.0.0/24 \
    --nic-name dockerbuildNIC \
    --os-type linux \
    --image-urn Canonical:UbuntuServer:16.04.0-LTS:latest \
    --storage-account-name dockerbuildstorage \
	--storage-account-container-name vhds \
    --os-disk-vhd osdisk.vhd \
    --admin-username dockeruser \
    --ssh-publickey-file "/config/keys/id_dockerBuild_rsa.pub"

~~~~

### Get the public IP from azure

~~~~

publicIPAddress=$(docker exec -it azureCli azure vm show dockerBuild dockerBuild |grep "Public IP address" | awk -F ":" '{print $3}' |tr -d '\r')

echo $publicIPAddress

~~~~

### Updating our VM

Unfortunately just proceeding to install the Docker Extensions will fail unless we run an `apt-get update` in the VM.

~~~~

ssh -o StrictHostKeyChecking=no dockeruser@$publicIPAddress -i ./keys/id_dockerBuild_rsa 'sudo apt-get update'

~~~~

### Creating TLS Certificates and CA
Nothing new here, we are creating the TLS certificates just like in part 1... 

~~~~

cd certs
openssl genrsa -aes256 -out ca-key.pem 4096

openssl req -new -key ca-key.pem -x509 -sha256 -days 365 -subj /CN=dockerbuildsystem.westus.cloudapp.azure.com -out ca.pem

openssl genrsa \
  -out server-key.pem $STR

openssl req -subj /CN=dockerbuild.harebrained-apps.com -new -sha256 -key server-key.pem -out server.csr

echo subjectAltName=IP:10.0.0.4,IP:$publicIPAddress,IP:127.0.0.1,DNS:dockerbuild.harebrained-apps.com,DNS:dockerbuildsystem.westus.cloudapp.azure.com > extfileServer.cnf

openssl x509 -req -days 365 -sha256 -in server.csr -CA ca.pem -CAcreateserial -CAkey ca-key.pem -out server-cert.pem -extfile extfileServer.cnf

openssl genrsa -out key.pem 4096

openssl req -subj /CN=client -new -key key.pem -out client.csr

echo extendedKeyUsage = clientAuth > extfile.cnf

openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -extfile extfile.cnf

rm -v client.csr server.csr

chmod -v 0400 ca-key.pem key.pem server-key.pem
chmod -v 0444 ca.pem server-cert.pem cert.pem

~~~~

### Convert certs to base64
In order to send the TLS certificates up to Azure we need to convert them to base 64...

~~~~

CA_BASE64="$(cat ca.pem | base64)"
CERT_BASE64="$(cat server-cert.pem | base64)"
KEY_BASE64="$(cat server-key.pem | base64)"

~~~~

Then we will create two configuration files. One that is public and one that should be protected (since it contains your TLS certificate information)

~~~~

echo "{
    \"docker\":{
        \"port\": \"2376\"
    }
}" > pub.json

echo "{
    \"certs\": {
        \"ca\": \"$CA_BASE64\",
        \"cert\": \"$CERT_BASE64\",
        \"key\": \"$KEY_BASE64\"
    }
}" > prot.json

~~~~

### Install the Docker Extensions on our VM

~~~~

docker exec -it azureCli azure vm extension set dockerBuild dockerBuild DockerExtension Microsoft.Azure.Extensions '1.0' --auto-upgrade-minor-version --public-config-path "/config/certs/pub.json" --private-config-path "/config/certs/prot.json"

~~~~

### Verify the connection
We will use the --tlsVerify flag with Docker, and also tell it what CA to use and what client keys to use and what host to connect to (including port). Once we do all of that we can run any Docker command on the remote host, let's simply get the version info

~~~~

docker --tlsverify --tlscacert=ca.pem --tlscert=cert.pem --tlskey=key.pem -H=tcp://$publicIPAddress:2376 version

~~~~

### Conclusion and Next Steps
In this part of the tutorial we've duplicated the efforts of Part 1 using only the command line. In a future post we will take this one step further and script (bash) the whole process.   

### Resources
Video Tutorial: [https://youtu.be/wFDuW1TQBbY](https://youtu.be/wFDuW1TQBbY)



