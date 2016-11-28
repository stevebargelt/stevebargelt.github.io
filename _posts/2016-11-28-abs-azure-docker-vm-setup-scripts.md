---
layout: post
title: 'Automated Build System Part 1.75: Docker in a VM in Azure via shell scripts and the Azure CLI'
subtitle: 
portfolio:  
thumbimage: '/assets/azure_docker_jenkins_small.png'
image: '/assets/azure_docker_jenkins.png'
author: Steve Bargelt
category: devops
tags: [jenkins, cd, ci, docker, azure, registry, docker hub]
excerpt_separator: <!--more-->
---

### Introduction

Welcome back to my Automated Build System series of tutorials. In part one of this series we used the Azure Portal web interface to setup a Linux VM in Azure, installed Docker on that VM and setup secure communication to the remote Docker host. In part 1.5 we used the Azure CLI to accomplish the same outcome. In this installment we will go oen step further and script out the Azure CLI and TLS generation commands to (almost) automated the creation of the base of our Automated Build System. I'm calling this part 1.75 since this is just another way to accomplish what we did in parts 1 and 1.5. If you are happy with using the Azure portal or manually running the CLI commands then you can skip right to Part 2.

<!--more-->

{% include abs.md %}
<br/>

### Prerequisties
Docker, open-ssh, Azure account 

>Note that in this series I assume you’re on a computer similar to mine (a Macbook running MacOS). It's certainly not a requirement to do this stuff though. You could be on Linux or Windows as a client, though some of the client-side tooling changes around a bit. I'm confident that you will figure it out!

### The Scripts
The scripts can be found at [https://github.com/stevebargelt/absSetupScripts](https://github.com/stevebargelt/absSetupScripts). Lets start by cloning this repo.

~~~~

git clone https://github.com/stevebargelt/absSetupScripts

cd absSetupScripts

~~~~

### Customization

The main script is abs_create.sh. Let's take a look inside. You **should** setup your naming conventions in the first 25 lines or so. The next 50 lines or so are where you can **optionally** name the components of your installation and change things like your internal IP address and your vnet and subnet IP address range.

### The Azure CLI Docker Container

The first thing the script does is try to determine if the Azure CLI Docker container is running and if not, start it. If it is not around then it will try to run it `docker run -td --name azureCli -v $SCRIPTS_LOCATION:/config microsoft/azure-cli` and map the current location to a volume in the container so we have access to config files, keys, and certificates. As of right now this code certainly isn't foolproof but I'm looking to improve it over time and I welcome PRs and suggestions from the communitity. 

### Creating SSH Keys

The default is to create the SSH keypair in `./keys/$NAME` where name is the name of your system... so in our case that would be `dockerBuild`.

### Creating the VM and the Prerequisties

The majority of the rest of this script creates the prerequisties (vnet, security rules, IP address, etc.) for our VM and the sends the command to actually create the VM. Once the VM is provisioned we grab the public IP address from Azure.  `docker exec -it azureCli azure vm show $rgName $vmName |grep "Public IP address" | awk -F ":" '{print $3}' |tr -d '\r'`

### Updating the VM

Next we run `apt-get update` on our VM. Becasue of an issue with the Azure VM provisioning, if we try to install the Docker extensions on our VM without doing this first the install fails.

### TLS Certs

We must create the CA, certificates, and keys for secure docker communication just like in part 1 and 1.5 - `abs_create.sh` calls `create-docker-tls.sh` to accomplish this. This script follows the steps that we've already covered. The certs are placed in ./certs/NAME - in our examples that would be ./certs/dockerBuild.

>NOTE: You will have to enter a password for the CA key several times during this step. 

### Install Docker Extension on VM

Finally the script calls out to yet another script `add-docker-ext.sh` to add the Docker extensions to our VM. That shell script converts the ca, cert, and server-key to base64, creates the configuration files pub.json and prot.json then uses the Azure CLI to install the extensions. 

### Conclusion and Next Steps

In this part of the tutorial we've automated the process of creating our VM in Azure and installing Docker exntension on that VM. We also create the TLS certs and keys necessary to establish secure communications with our Docker host on that VM. 

Throughout the remainder of this tutorial I will build on these scripts so we have less and less manual work to do to create or re-create our Automated Build System.
