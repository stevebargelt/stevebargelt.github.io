---
layout: post
title: 'Automated Build System Part 03: Secure Docker Registry in Azure'
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

Welcome back to my series where we are creating an Automated Build System with Docker and Jenkins in Azure. In part one we setup a Linux  VM in azure, installed Docker on that VM and setup secure communication to the Docker host. In part two we used a custom Jenkins Docker image to stand-up our Jenkins master and created a simple sample build job that spins up an ephemeral Docker container slave node.

<!--more-->

{% include abs.md %}

Since our ultimate goal is to allow our developers to create their own Docker images for their build environments we need a good way for them to insert them into the system. So in this installment we are going to stand up a private Docker registry in Azure and secure it with TLS/SSL certificates from letsencrypt. 

Here is a diagram of what we will have at the end of this part of the tutorial:

[![build system diagram](/assets/buildSystem_03_small.png){: .img-responsive }](/assets/buildSystem_03.png){: .img-blog }

The video tutorial:

<br/>

Lets get rollin'.

### More Inbound Security Rules 

The first thing we will need to do is open two ports in Azure to our VM, 443 for https communication to Jenkins and 5000 for https communication to our Docker registry. We can do this in the Azure portal like we did in part one... 

1. Click the resource group, dockerBuild 
2. Now we need to open a port for registry communication...
3. select our network security group
4. select Inbound Security Rules
5. click add
6. we are going to name this rule - allow-docker-registry
7. Port 5000
8. Leave the rest at their defaults 
9. Click okay

And now add a rule for SSL communication:

1. Click Add again...
1. We are going to name this rule - allow-https
1. Select from the drop-down HTTPS
1. Leave the rest at their defaults 
1. Click okay


Or we can use the Azure Command Line Interface (CLI) from a Docker container like we did in part 1.5

~~~~

docker exec -it azureCli azure network nsg rule create --protocol tcp \
    --direction inbound \
    --priority 1040 \
    --destination-port-range 5000 \
    --access allow \
    --resource-group dockerBuild \
    --nsg-name dockerBuild-nsg \
    --name allow-docker-registry

docker exec -it azureCli azure network nsg rule create --protocol tcp \
    --direction inbound \
    --priority 1050 \
    --destination-port-range 443 \
    --access allow \
    --resource-group dockerBuild \
    --nsg-name dockerBuild-nsg \
    --name allow-https

~~~~

While we are modifying our Azure setup we also need to add a blob storage account because we are going to configure our Docker Registry to store images in blob storage... how cool is that? Let's get that out of the way as well. 

Select our Resource group... 

* Click Add
* Search for "Storage"
* Click Storage Account
* Click Create

* name: dockerbuildregistry
* Deployment Model: Resource Manager
* Account Kind: Select "Blob Storage"
* Performance: Standard
* Replication: LRS
* Access Tier: Hot
* Encryption: Disabled
* Subscription: Yep
* Use Existing: dockerBuild
* Location: westus

Click create

OF course we can create storage account via the CLI instead:

~~~~

docker exec -it azureCli azure storage account create --resource-group dockerbuild --kind BlobStorage --sku-name LRS --access-tier Hot --location westus2 dockerbuildregistry

~~~~

I will also add these inbound security rules and the blob storage account creation to the shell scripts we created in part 1.75 - these scripts are located on github: [https://github.com/stevebargelt/absSetupScripts](https://github.com/stevebargelt/absSetupScripts).

In part 2 we cloned my jenkinsDocker github repo to our VM. The repo includes a Dockerfile definition for a letsencrypt container. That's right we are going to run letsencrypt in a Docker container on our VM to obtain our TLS certificates! In order to do that we need to stop our running containers... remember that we have the Data container so that all of our Jenkins settings, including our cloud setup, Docker templates, and build jobs will persist!!

~~~~

ssh dockeruser@dockerbuild.harebrained-apps.com
cd jenkinsDocker
docker-compose -p jenkins stop

~~~~

## Get Legit with letsencrypt

Alright let's get legit with real trusted TLS certificates. We need to build the letsencrypt image

~~~~

cd letsencrypt
docker build -t letsencrypt .

~~~~

And then create the directory for letsencrypt to place our certificate goodies in...

~~~~

mkdir -p /etc/letsencrypt

~~~~

Run the letsencrypt container to do it's thing - we are mapping port 80 to 80 and 443 to 443

~~~~

docker run  -v /etc/letsencrypt:/etc/letsencrypt -p 80:80 -p 443:443 -it --name letsencrypt letsencrypt

~~~~

This runs and attaches us to our letsencrypt container. Now we can ask letsencrypt to create the certificates for our domain names (remember back in part one - I insisted you use your own personal custom domain names? You won't be able to complete this if you are using a domain that ends in azure.com or cloudapp.com since you do not own those root domains).

My jenkins DNS is dockerbuild.harebrained-apps.com 

~~~~

cd letsencrypt
./letsencrypt-auto certonly --standalone -d dockerbuild.harebrained-apps.com

~~~~
Enter email address
Agree to Terms of service

Congratulations message!

One more time for our private registry, our Docker registry DNS is dockerregistry.harebrained-apps.com:

~~~~

./letsencrypt-auto certonly --standalone -d dockerregistry.harebrained-apps.com

~~~~

Sweet - all certificate'd up! We can exit out of our letsencrypt container

~~~~

exit

~~~~

As the letsencrypt messages say letsencrypt put all of our certificate files in... 


/etc/letsencrypt/live/dockerbuild.harebrained-apps.com
	and
/etc/letsencrypt/live/dockerregistry.harebrained-apps.com

> these are the files letsencrypt makes in the above folder
	cert.pem: Your domain's certificate
	chain.pem: The Let's Encrypt chain certificate
	fullchain.pem: cert.pem and chain.pem combined
	privkey.pem: Your certificate's private key


We need to tell NGINX where to find fullchain.pem and privkey.pem for both domains/servers.
 First lets edit  registry.conf...

~~~~

cd jenkins-nginx/conf
nano registry.conf

~~~~
IMG 

Next we will edit jenkins.conf 

~~~~

nano jenkins.conf

~~~~
IMG 


Now we need to create the basic authentication using htpassword tool, which we must install first from apache utils...

~~~~

cd ..

sudo apt install apache2-utils
mkdir ~/jenkinsDocker/jenkins-nginx/files
cd ~/jenkinsDocker/jenkins-nginx/files

htpasswd -c registry.password dockeruser

~~~~

Enter the password twice... and we have our user. You can add other users to the file as needed. We will explore hooking the up to other auth methods in a later tutorial if there is interest.

Next we need to modify the jenkins-ngix dockerfile:

~~~~

cd jenkins-nginx
nano Dockerfile 

~~~~

UNCOMMENT:
#COPY conf/registry.conf /etc/nginx/conf.d/registry.conf
#COPY files/registry.password /etc/nginx/conf.d/registry.password
And:
#EXPOSE 443

IMG

Finally we need to edit our docker-compose.yml to add the registry container to our project so it will startup when our build system starts up... 

~~~~

cd ..
nano docker-compose.yml

~~~~

Remember I said we are going to hook our registry up to our Azure blob storage account... here is where we do that. We ned to KEY from our storage account... 

Uncomment the entire registry section under nginx links... uncomment:

- registry:registry

* Add account name "dockerbuildregistry"

> PORTAL

copy key 1 access key 
We can also get this form the azure CLI (I'm sure you are not surprised!)

**NEW TERMINAL WINDOW** 

~~~~

docker ps -a

~~~~

* copy KEY 1
* exit TERM window 2 
* place the cursor for the key and PASTE
* CTRL-X to exit Y to save changes
* ENTER on file name


### Restart our Jenkins Docker deployment

We will use docker compose to restart our system. This time we will add the registry container to the "up" command

~~~~

docker-compose -p jenkins rm nginx
docker rmi jenkins_nginx:latest
docker-compose -p jenkins up -d nginx data master registry

~~~~

Lets see what containers we have running 

~~~~

docker ps -a

~~~~

We can see that jenkins_nginx, jenkins_master, and jenkins_data are all running just like before, and now registry is also running. Let's test our registry out over https.   

~~~~

curl -iv https://dockeruser:steel2000@dockerregistry.harebrained-apps.com/v2/

~~~~

See if we can get to Jenkins over https : https://dockerbuild.harebrained-apps.com/ 

Yes! Now our Jenkins installation is secure. One Jenkins configuration setting we need to change... 

Manage Jenkins > Configure  > System 
Jenkins Location
 	Jenkins URL

Now let's see if we can push an image to our new (secure) registry

~~~~

docker images

$ docker images
REPOSITORY            TAG                 IMAGE ID            CREATED             SIZE
jenkins_nginx         latest              384b54f02274        About an hour ago   56.94 MB
letsencrypt           latest              43bc8b12c968        About an hour ago   478.9 MB
jenkins_slave         latest              4c92758529cd        20 hours ago        713.1 MB
jenkins_master        latest              4e26a37f5f49        20 hours ago        302.4 MB
jenkins_data          latest              8e3431915555        20 hours ago        196.8 MB
jenkins_slavedotnet   latest              d12919ef962a        20 hours ago        1.056 GB
...

docker tag 

**COPY ID**
**PASTE** dockerregistry.harebrained-apps.com/jenkins-slave

docker login dockerregistry.harebrained-apps.com 
	dockeruser
	steel2000

docker push dockerregistry.harebrained-apps.com/jenkins-slave

~~~~

Lets pop back over into the Azure portal to check out our storage account... dockerbuildregistry, click overview, blobs - here you can see we now have a blob container named "registry" 

~~~~

docker rmi -f dockerregistry.harebrained-apps.com/jenkins-slave
docker pull dockerregistry.harebrained-apps.com/jenkins-slave

~~~~

we have now successfully pushed our dot net build slave to our private registry 

> celebrate, make a little glove, get down tonight

In this tutorial we created a secure docker registry and also secured our Jenkins installation with TLS certs from letsencrypt. We have all of the major pieces of our build system in place! In the next installment we will talk about custom scripts in Jenkins - and exposing those scripts in an API-like fashion. 

Image link:
[![](/assets/-small.png){: .img-responsive }](/assets/.png){: .img-blog }


### Conclusion and Next Steps
In this part of the tutorial we've 

In the next installment we are going to  

### Resources
Video Tutorial: []()
