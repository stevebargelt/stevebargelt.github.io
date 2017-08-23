---
layout: post
title: 'Automated Build System 03: Secure Docker Registry in Azure'
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

The video tutorial for Part 3:
<iframe width="560" height="315" src="https://www.youtube.com/embed/ivIoShwx6dE" frameborder="0" allowfullscreen></iframe>
<br/>

>Note that in this series I assume you’re on a computer similar to mine (a Macbook Pro running MacOS). It's certainly not a requirement to do this stuff though. You could be on Linux or Windows as a client, though some of the client-side tooling changes around a bit. I'm confident that you will figure it out!
<br/>

Lets get rollin'.

### Inbound Security Rules 

The first thing we will need to do is open two ports in Azure to our VM, 443 for https communication to Jenkins and 5000 for https communication to our Docker registry. We can do this in the Azure portal like we did in part one... 

1. Click the resource group (dockerBuild) 
3. Click our network security group (dockerbuild-nsg)
4. Select Inbound Security Rules
5. Click Add (+ symbol)
6. Name this rule - allow-docker-registry
7. Port 5000
8. Leave the rest at their defaults 
9. Click okay

[![Azure Inbound Security Rule for port 5000](/assets/abs-03-azure-security-docker-registry-small.png){: .img-responsive }](/assets/abs-03-azure-security-docker-registry.png){: .img-blog }

And now add a rule for SSL communication to Jenkins:

1. Click Add again
1. We are going to name this rule - allow-https
1. Select from the drop-down HTTPS
1. Leave the rest at their defaults 
1. Click okay

[![Azure Inbound Security Rule for port 443](/assets/abs-03-azure-secutry-add-https-small.png){: .img-responsive }](/assets/abs-03-azure-secutry-add-https.png){: .img-blog }

Alternatively we can use the Azure Command Line Interface (CLI) from a Docker container like we did in part 1.5

```shell

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

```

### Blob Storage Account

While we are modifying our Azure setup we also need to add a blob storage account because we are going to configure our Docker Registry to store images in blob storage... how cool is that? Let's get that out of the way as well. 

Select our Resource group... 

1. Click Add
1. Search for "Storage"
1. Click Storage Account
    [![](/assets/abs-03-azure-storage-account-small.png){: .img-responsive }](/assets/abs-03-azure-storage-account.png){: .img-blog }

1. Click Create

* name: dockerbuildregistry
* Deployment Model: Resource Manager
* Account Kind: Select "Blob Storage"
* Performance: Standard
* Replication: LRS
* Access Tier: Hot
* Encryption: Disabled
* Use Existing Resource Group: dockerBuild
* Location: westus

[![](/assets/abs-03-azure-create-blob-storage-small.png){: .img-responsive }](/assets/abs-03-azure-create-blob-storage.png){: .img-blog }

Click create

Of course we can create storage account via the CLI instead:

```shell

docker exec -it azureCli azure storage account create --resource-group dockerbuild --kind BlobStorage --sku-name LRS --access-tier Hot --location westus2 dockerbuildregistry

```

<p>&nbsp;</p>

>### ABS Setup scripts
>I will add these two inbound security rules and the blob storage account creation commands to the shell scripts we created [in part 1.75]({% post_url 2016-11-28-abs-azure-docker-vm-setup-scripts %}) - these scripts are located on github: [https://github.com/stevebargelt/absSetupScripts](https://github.com/stevebargelt/absSetupScripts).


## Get Legit with letsencrypt

In [part 2]({% post_url 2016-10-31-automated-build-system-part-custom-containers %}) we cloned my [jenkinsDocker github repo](https://github.com/stevebargelt/jenkinsDocker) to our VM. The repo includes a Dockerfile definition for a [letsencrypt](https://letsencrypt.org) container. That's right we are going to run letsencrypt in a Docker container on our VM to obtain our TLS certificates! In order to do that we need to stop our running containers... remember that we have the Data container so that all of our Jenkins settings, including our cloud setup, Docker templates, and build jobs will persist!!

### Stop our containers

```shell

ssh dockeruser@dockerbuild.harebrained-apps.com
cd jenkinsDocker
docker-compose -p jenkins stop

```

### Build and run the letsencrypt container

We need to build the letsencrypt image:

```shell

cd letsencrypt
docker build -t letsencrypt .

```

And then create the local directory for letsencrypt to place our certificate goodies in:

```shell

mkdir -p /etc/letsencrypt

```

Run the letsencrypt container to do it's thing - we are mapping the local etc/letsencrypt to the same directory in the container and we are mapping port 80 to 80 and 443 to 443

```shell

docker run  -v /etc/letsencrypt:/etc/letsencrypt -p 80:80 -p 443:443 -it --name letsencrypt letsencrypt

root@b7d70459bd4c:/#

```

### Create our certificates

This runs and attaches us to our letsencrypt container. Now we can ask letsencrypt to create the certificates for our domain names (remember back in part one - I insisted you use your own personal custom domain names? You won't be able to complete this if you are using a domain that ends in azure.com or cloudapp.com since you do not own those root domains).

The domain name we are using for Jenkins in this tutorial is: dockerbuild.harebrained-apps.com - obviously replace this with your own domain name.

```shell

cd letsencrypt
./letsencrypt-auto certonly --standalone -d dockerbuild.harebrained-apps.com

```

1. Enter your email address
1. Agree to Terms of service

Congratulations message!

One more time for our private registry, our Docker registry domain name is: dockerregistry.harebrained-apps.com - again you are going to replace this with your own domain name.

```shell

./letsencrypt-auto certonly --standalone -d dockerregistry.harebrained-apps.com

```

Sweet - all certificate'd up! We can exit out of our letsencrypt container

```shell

exit

```

As the letsencrypt messages say letsencrypt put all of our certificate files in

```shell 

/etc/letsencrypt/live/dockerbuild.harebrained-apps.com
/etc/letsencrypt/live/dockerregistry.harebrained-apps.com

```

The files letsencrypt makes in the above folder:

* cert.pem: Your domain's certificate
* chain.pem: The Let's Encrypt chain certificate
* fullchain.pem: cert.pem and chain.pem combined
* privkey.pem: Your certificate's private key

### Configure NGINX

We need to tell NGINX where to find fullchain.pem and privkey.pem for both domains/servers - we do that through NGINX .conf files. First lets edit registry.conf:

```shell

cd jenkins-nginx/conf
nano registry.conf

```

Replace <YOUR DOMAIN NAME> with, you guessed it, your domain name in three locations in this file. 

[![](/assets/abs-03-nano-registry-conf-small.png){: .img-responsive }](/assets/abs-03-nano-registry-conf.png){: .img-blog }

CTRL-X, Y, Enter to save the changes

Next we will edit jenkins.conf 

```shell

nano jenkins.conf

```

We need to do a bit more work in jenkins.conf since it was already in use supporting our http instance of Jenkins. 

1. Switch listen 80; to listen 443;
1. Add a server name: server_name dockerbuild.harebrained-apps.com;
1. Right before access_log off; Add
    1. ssl on;
    1. ssl_certificate /etc/letsencrypt/live/dockerbuild.harebrained-apps.com/fullchain.pem;
    1. ssl_certificate_key /etc/letsencrypt/live/dockerbuild.harebrained-apps.com/privkey.pem;

[![](/assets/abs-03-nano-jenkins-conf-small.png){: .img-responsive }](/assets/abs-03-nano-jenkins-conf.png){: .img-blog }

> obviously replacing dockerbuild.harebrained-apps.com with your Jenkins domain name!

CTRL-X, Y, Enter to save the changes

Now we need to create the basic authentication file using htpassword tool, which we must install first from apache utils...

```shell

sudo apt install apache2-utils

```

### Create a basic auth user

Now we will create a user names "dockeruser"

```shell

mkdir ~/jenkinsDocker/jenkins-nginx/files
cd ~/jenkinsDocker/jenkins-nginx/files
htpasswd -c registry.password dockeruser

```

Enter a password twice... and we have our user. You can add other users to the file as needed. 

### NGINX Dockerfile

Next we need to modify the jenkins-ngix Dockerfile to copy registry.conf and registry.password into the image and we need to expose port 443:

```shell

cd jenkins-nginx
nano Dockerfile 

```

Uncomment:

1. COPY conf/registry.conf /etc/nginx/conf.d/registry.conf
1. COPY files/registry.password /etc/nginx/conf.d/registry.password
1. EXPOSE 443

[![](/assets/abs-03-nano-nginx-dockerfile-before-small.png){: .img-responsive }](/assets/abs-03-nano-nginx-dockerfile-before.png){: .img-blog }
[![](/assets/abs-03-nano-nginx-dockerfile-small.png){: .img-responsive }](/assets/abs-03-nano-nginx-dockerfile.png){: .img-blog }

CTRL-X, Y, Enter to save the changes

### Modify docker-compose 

Finally we need to edit our docker-compose.yml to add the registry container to our project so docker knows how to build it.

```shell

cd ..
nano docker-compose.yml

```

[![](/assets/abs-03-nano-docker-compose-before-small.png){: .img-responsive }](/assets/abs-03-nano-docker-compose-before.png){: .img-blog }

1. Uncomment the entire registry section under nginx links
1. Uncomment `- registry:registry` under the NGINX heading.

I said we are going to hook our registry up to our Azure blob storage account... here is where we do that. We ned to KEY from our storage account... 

In the Azure portal, click on your Resource Group (dockerbuild) -> 
Click your registry storage account (dockerbuildregistry) -> 
Click Access Keys
Copy one of the access keys 

[![](/assets/abs-03-azure-reg-storage-accesskeys-small.png){: .img-responsive }](/assets/abs-03-azure-reg-storage-accesskeys.png){: .img-blog }

We can also get this form the azure CLI (I'm sure you are not surprised!)

```shell

docker exec -it azureCli azure storage account keys list  dockerbuildregistry --resource-group dockerbuild

```

* PASTE The access key

CTRL-X, Y, Enter to save the changes

[![](/assets/abs-03-nano-docker-compose-small.png){: .img-responsive }](/assets/abs-03-nano-docker-compose.png){: .img-blog }

### Restart our Jenkins Docker deployment

We will use docker compose to rebuild our NGINX image and then to restart our system. This time we will add the registry container to the "up" command

```shell

docker-compose -p jenkins rm nginx
docker rmi jenkins_nginx:latest
docker-compose -p jenkins up -d nginx data master registry

```

Lets see what containers we have running 

```shell

docker ps -a

```

We can see that jenkins_nginx, jenkins_master, and jenkins_data are all running just like before, and now registry is also running. Let's test our registry out over https.   

```shell

curl -iv https://dockeruser:<PASSWORD>dockerregistry.harebrained-apps.com/v2/

```

> NOTE: Due to a change made recently the docker registry will return a 503 error because a "Health Check" fails with an empty registry store (like our Azure storage). I've written a new blog post on how to remedy this situation - link coming soon. (Updated 2017-08-23)

See if we can get to Jenkins over https : 

* https://dockerbuild.harebrained-apps.com/ 

Yes! Now our Jenkins installation is secure. One Jenkins configuration setting we need to change... 

Manage Jenkins > Configure  > System 
Jenkins Location
 	Jenkins URL

Now let's see if we can push an image to our new (secure) registry. First let's fetch the Image ID of our jenkins-slave image and tag that image with our registry:

[![](/assets/abs-03-cli-jenkins-slave-image-id-small.png){: .img-responsive }](/assets/abs-03-cli-jenkins-slave-image-id.png){: .img-blog }

```shell

docker tag 5d3aa1c6c363 dockerregistry.harebrained-apps.com/jenkins-slave

```

[![](/assets/abs-03-cli-slave-image-tagged-small.png){: .img-responsive }](/assets/abs-03-cli-slave-image-tagged.png){: .img-blog }

Next we will login to our registry on the command line and then push this image to our private registry where it will be stored in our Azure blob storage

```shell

docker login dockerregistry.harebrained-apps.com 
	dockeruser
	<PASSWORD>

docker push dockerregistry.harebrained-apps.com/jenkins-slave

```

If we pop over into the Azure portal we can see the image and layers in the dockerbuildregistry storage account.

1. Click overview
1. Click blobs - here you can see we now have a blob container named "registry"
1. Click registry
1. You can then drill-down into the folder structure to see the image (jenkins-slave) 

[![](/assets/abs-03-azure-registry-image-small.png){: .img-responsive }](/assets/abs-03-azure-registry-image.png){: .img-blog }

and drill down even further to see the layer blobs.

[![](/assets/abs-03-azure-registry-layers-small.png){: .img-responsive }](/assets/abs-03-azure-registry-layers.png){: .img-blog }

This is pretty cool. We have now successfully pushed our build slave image to our private registry! 

### Conclusion and Next Steps
In this tutorial we created a secure docker registry and also secured our Jenkins installation with TLS certs from letsencrypt. 

Our private Docker registry is a fundamental piece of our final build system puzzle. Our tool, Dockhand, will push our dev teams' build images to the private registry so that they are available to the rest of our build system. Once in the registry we can pull those images to our Jenkins master(s) so they can be used as Jenkins slave nodes for build jobs.   

We now have all of the major pieces of our build system in place! We have one more small piece of work to do before we can let this loose on our dev teams. In the next installment we will talk about custom scripts in Jenkins and exposing those scripts in an API-like fashion. Dockhand will need to be able to create Docker templates and check that build labels and build job names are unique. Since the our of the box Jenkins API does not expose all of this to us, we will be exposing that functionality through a custom Jenkins script. 

Where we will concentrate in Part 4:
[![build system diagram](/assets/buildSystem_04_small.png){: .img-responsive }](/assets/buildSystem_04.png){: .img-blog }

### Resources
Video Tutorial: [Part 3](https://youtu.be/ivIoShwx6dE)
