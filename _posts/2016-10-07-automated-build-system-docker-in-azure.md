---
layout: post
title: 'Automated Build System Part 1: Docker in Azure'
subtitle: 
portfolio:  
thumbimage: '/assets/azure_docker_jenkins_small.png'
image: '/assets/azure_docker_jenkins.png'
author: Steve Bargelt
category: devops
tags: [jenkins, cd, ci, docker, azure, riot games]
---

### Introduction
Welcome to part one of my Automated Build System (ABS) series. Where we are building a fully functional, hands-off build system using Docker and Jenkins... all in Azure. 

{% include abs.md %}

In this first installment we will be setting up Docker in Azure on a Linux VM. Of course, there are several ways to accomplish this and I'm only going to walk through one possible solution in this tutorial. After we get this system up and running smoothly, I will explore other options for setting up the base system such as using the Azure command line interface (CLI).

I know Microsoft recently announced that Windows Server 2016 will include Docker, and that is awesome! I'm very excited about Docker being truly cross-platform. After we get this build system running smoothly in Linux I will explore expanding the system to include Windows. 

Here is a diagram of what we will have at the end of this tutorial:

[![build system diagram](/assets/buildSystem_01_small.png){: .img-responsive }](/assets/buildSystem_01.png){: .img-blog }

It may not look like much but it's the foundation for the system we are going to build. 

The video tutorial:
<iframe width="560" height="315" src="https://www.youtube.com/embed/P7dGzLa4BHY" frameborder="0" allowfullscreen></iframe>
<br/>

### Adding an Ubuntu VM to Azure
Head over to the [Azure portal](http://portal.azure.com). Click the New button in the left tray, search for Docker and several options appear; Docker on Ubuntu seems like the obvious choice since that is ultimately what we are trying to setup. Unfortunately it's not that simple, one problem is that only allows you to select the classic deployment model and also doesn't set up Docker for TLS and secure communication. Sure we can live with the classic model and we can configure secure Docker ourselves, but there is a better option. 

Go back and search for Ubuntu and click the latest LTS release, currently 16.04. 

Make sure the Deployment model is Resource Manager and click Create.

I am going to name this VM *dockerBuild*

One thing to note here is that you can save some money if you choose HDD - magnetic disks instead of solid state drives. Choosing HDD here opens up possibility so of cheaper plans which we will see in the next step. 

Our admin user will be dockerUser and we are going to use SSH keys to authenticate and not username/password.

### Creating SSH keys
Open a terminal to create the public/private key pair. The C flag is just a comment - it's appended onto the end of the public key and it will serve as a reminder of what this keypair is for. We're not going to add a passphrase and we are going to name the files so that we have a clue as to what they are for ~/.ssh/id_dockerbuild_rsa.

~~~~

$ ssh-keygen -t rsa -b 2048 -C "steve@dockerbuildAzureVM"

Generating public/private rsa key pair.
Enter file in which to save the key (/Users/steve/.ssh/id_rsa): /Users/steve/.ssh/id_dockerbuild_rsa
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /Users/steve/.ssh/id_dockerbuild_rsa.
Your public key has been saved in /Users/steve/.ssh/id_dockerbuild_rsa.pub.
The key fingerprint is:
SHA256:zy0VHseXTQUINXvEErBkmVHAFhvq0RBNdsrmTlWWkp8 steve@dockerbuildAzureVM

➜  
~~~~

We need to add this identity to  our ssh agent so that it is usable on our system. first we'll check to see if the ssh-agent is running... with eval...  

~~~~

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_dockerbuild_rsa

~~~~

Finally we need to copy the public key to the clipboard. I'm on a Mac so I'm using "pbcopy" if you aren't you can open the key in a text editor or simply $ cat the contents to the terminal screen and copy from there.

~~~~
pbcopy < ~/.ssh/id_dockerbuild_rsa.pub
~~~~

Back in our browser, paste in the key. you can see our -C comment is here in the public key

We are going to create a new resource group and name it dockerBuild, I'm in Seattle so I'm chosing westus as the location. 

[![azure vm basic settings](/assets/azure-vm-basics_small.png){: .img-responsive }](/assets/azure-vm-basics.png){: .img-blog }

Click OK

### Pick Your Plan
Alright next we need to choose a plan for our VM. You will notice that even if you click View All we can't see the "A" plans that can be as cheap as $15 per month because I decided to leave the SSD selected. In preparing for this tutorial - I found that using the cheaper plans with the magnetic spinning disks made the Docker host run unbearably slow. So I'll pick the DS1_V2 Standard. 

[![azure vm plan picking DS1_V2](/assets/azure-pick-plan-small.png){: .img-responsive }](/assets/azure-pick-plan.png){: .img-blog }

Click Select

### More VM Settings
I am leaving all of the default names here for the storage account and all of the networking components. Over the past couple years of working with resources in the cloud, I've found that I don't care about machine / resource names. I used to plan out resource names, even going with themes like Lord of the Rings or Star Wars. Well now all of the resources are disposable and easily destroyed and rebuilt so names just don't matter to me any more. I'm not going to setup a high availability set either. So I am going with all of the defaults. Click okay. 

[![azure vm settings](/assets/azure-vm-settings_small.png){: .img-responsive }](/assets/azure-vm-settings.png){: .img-blog }

Azure validates the build, give us a quick summary. Click okay one more time and Azure starts provisioning the VM for us.

### VM Preparation
Once Azure has completed it's work, back to the Azure portal. Click on Resource Groups.

Click on dockerBuild (Resource Group), this gives us a view of our newly provisioned VM and supporting cast including all of the networking and storage components. 

Click on dockerBuild (the VM). Then click on the IP address.

Add a DNS name to our IP settings... Click Configuration - I will use dockerbuildsys

We want to take note of the public IP address and DNS name for our VM... so I'll open a text editor, Visual Studio Code is my current favorite, to take a few notes.  

Click Save

Copy the DNS and IP, paste them in a text editor. 

I will also point a custom DNS name at this VM. Later in this series we're going to get TLS certificates from [letsencrypt](https://letsencrypt.org) for secure https communication to our private Docker registry. We will must have a custom domain name to make that happen. The quick reason is that Azure domains are secured by wildcard certs which won't work for our purposes. _If you don't have a domain name I strongly suggest that you obtain one so that we can establish secure communication with our private Docker Registry (and Jenkins)._ 

All name providers are different and you can google for how to add an a-record at yours. At my provider in the Host Records interface I will just paste the public IP address into the A-record for the domain name I want to use _dockerbuild.harebrained-apps.com_. 

[![host a-record](/assets/host-a-record-small.png){: .img-responsive }](/assets/host-a-record.png){: .img-blog }

Here are my notes so far:

* 40.78.31.164
* dockerbuild.harebrained-apps.com
* dockerbuildsys.westus.cloudapp.azure.com

We will be adding our local IP address to this list shortly. 

### SSH to our VM
Azure already opened up port 22 for SSH communication, very thoughtful of Microsoft. 

Connect via SSH - we'll use our custom domain name.

~~~~

$ ssh dockeruser@dockerbuild.harebrained-apps.com

Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 4.4.0-38-generic x86_64)
...
To run a command as administrator (user "root"), use "sudo <command>".

dockeruser@dockerBuild:~$ 

~~~~

Connected! While we are in here we're going to grab the local/private IP address using the ifconfig command:

~~~~

$ ifconfig 

eth0      Link encap:Ethernet  HWaddr 00:0d:3a:30:21:a5  
          inet addr:10.0.0.4  Bcast:10.0.0.255  Mask:255.255.255.0
          inet6 addr: fe80::20d:3aff:fe30:21a5/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:1674984 errors:0 dropped:2 overruns:0 frame:0
          TX packets:567214 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:2252753926 (2.2 GB)  TX bytes:238825364 (238.8 MB)

~~~~

We want the inet addr for the eth0 adapter. We'll also copy that into our notes for use later. We can exit / logout of the SSH session.

~~~~

$ exit

logout
Connection to dockerbuild.harebrained-apps.com closed.
$

~~~~ 

Back into the Azure portal -- we need to open a few more ports for our system to work.

Click on dockerBuild (Resource Group) > Network Security Group, Inbound Security Rules, click add. 

The first rule we are going to add is for web/http access for our Jenkins server. HTTP is a preconfigured service you can pick from the Services drop-down. Lets name this **allow-http**, click ok.

Next we're going to add secure web / https communication. Select HTTPS from the Service drop down. We'll call this **allow-https**, click ok. 

Last one we are going to add for now, we are going open a port for secure Docker TLS communication. We'll call this **allow-docker-tls** and since this is not a preconfigured service so we have to make a couple more choices: 

* TCP as the protocol
* Port 2376 

Click OK

Our inbound security rules should now look about like this:

[![azure inbound rules image](/assets/azure-inbound-rules-small.png){: .img-responsive }](/assets/azure-inbound-rules.png){: .img-blog }

### TLS CA and Certs
We have one more thing to do before we install Docker in our VM. Docker uses [TLS](https://en.wikipedia.org/wiki/Transport_Layer_Security) with client certificates for authentication to communicate with remote hosts. Our Docker host daemon will only accept connections from clients authenticated by a certificate signed by that CA. So we will create our own certificate authority, server and client certs and keys. Interesting aside regarding self-signed client certs: [Trusted CA for Client Certs?](https://schnouki.net/posts/2015/11/25/lets-encrypt-and-client-certificates/)

For the sake of organization we are going to create a local folder to hold our CA and certs.

~~~~

mkdir tlsBuild
cd tlsBuild

~~~~

First we will create the certificate authority key and we must add a passphrase

~~~~

$ openssl genrsa -aes256 -out ca-key.pem 4096

Generating RSA private key, 4096 bit long modulus
..........................................++
...........++
e is 65537 (0x10001)
Enter pass phrase for ca-key.pem:
Verifying - Enter pass phrase for ca-key.pem:

~~~~

Next we will create the certificate authority itself... 

~~~~

openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem

Enter pass phrase for ca-key.pem:
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:US
State or Province Name (full name) [Some-State]:Washington
Locality Name (eg, city) []:Seattle
Organization Name (eg, company) [Internet Widgits Pty Ltd]:Harebrained Apps, LLC
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:harebrained-apps.com
Email Address []:steve@bargelt.com

~~~~
	
Now that we have a certificate authority, we can create a server key and certificate signing request (CSR) and with these we will create our server certificate. Make sure that “Common Name” or CN matches the hostname you will use to connect to Docker in my case that is my custom domain name.

~~~~

openssl genrsa -out server-key.pem 4096

openssl req -subj "/CN=dockerbuild.harebrained-apps.com" -sha256 -new -key server-key.pem -out server.csr

~~~~

Since the TLS connection can be made via IP address (between machines on the private network in Azure, localhost:127.0.0.1, and to the public IP address from external machines) in addition to two DNS names, we need to specify all of the DNS and IP options. This is done in a certificate extensions file. We will just echo the options out to that file... 

~~~~

echo subjectAltName = IP:40.78.31.164,IP:10.0.0.4,IP:127.0.0.1,DNS:dockerbuildsys.westus.cloudapp.azure.com,DNS:dockerbuild.harebrained-apps.com > extfile.cnf

~~~~

Finally we will actually create the server certificate

~~~~

openssl x509 -req -days 365 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -extfile extfile.cnf

~~~~

Server side done. Now for client authentication we will create a client key and certificate signing request which we will use to create our client cert

~~~~

openssl genrsa -out key.pem 4096

openssl req -subj '/CN=client' -new -key key.pem -out client.csr

~~~~

To make the certificate suitable for client authentication, update our certificate extensions 

~~~~

echo extendedKeyUsage = clientAuth > extfile.cnf

openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -extfile extfile.cnf

~~~~

After generating our client and server certificates, cert.pem and server-cert.pem, we can safely remove the two certificate signing requests.

~~~~

rm -v client.csr server.csr

~~~~

In order to protect your keys from accidental damage, you will want to remove write permissions and also make them only readable by you, change file modes as follows:

~~~~	

chmod -v 0400 ca-key.pem key.pem server-key.pem

~~~~

Certificates can be world-readable, but you might want to remove write access to prevent accidental damage:

~~~~

chmod -v 0444 ca.pem server-cert.pem cert.pem

~~~~

I guess this is as good of a time as any to bring this up... anyone with these keys can give any instructions to your Docker daemon, including giving them root access to the machine hosting the daemon. Guard these keys as you would a root password!

### Installing Docker in your VM
Back to the Azure portal...  

Click on dockerBuild (resource group) > dockerBuild (VM) 
	> Extensions > Click the Add Button > we want Docker (Microsoft) > Click create

You can see we've already done the prep work necessary here, we opened port 2376 and created the certs and keys we need.

Select the certificate authority, the server cert, the server key. Then click OK... Azure will go off and install Docker in our VM.

[![azure docker settings image](/assets/azure-docker-settings-small.png){: .img-responsive }](/assets/azure-docker-settings.png){: .img-blog }

### Connecting to a remote Docker host 
Once the provisioning has succeeded. We will connect to the Docker host we've just created. 

Flip over to our terminal... note that we are in the ~/tlsBuild folder which will save us some typing. We are going to use the --tlsVerify flag with Docker, and also tell it what CA to use and what client certificate and key to use and what host to connect to (including port). Once we do all of that we can run any Docker command on the remote host, let's simply get the version info

~~~~

$ cd ~/tlsBuild
$ docker --tlsverify --tlscacert=ca.pem --tlscert=cert.pem --tlskey=key.pem -H=dockerbuild.harebrained-apps.com:2376 version

Client:
 Version:      1.12.1
 API version:  1.24
 Go version:   go1.7.1
 Git commit:   6f9534c
 Built:        Thu Sep  8 10:31:18 2016
 OS/Arch:      darwin/amd64

Server:
 Version:      1.12.1
 API version:  1.24
 Go version:   go1.6.3
 Git commit:   23cf638
 Built:        Thu Aug 18 05:33:38 2016
 OS/Arch:      linux/amd64

~~~~

As you can see Docker gives us the client and server version information both running Docker 1.12.1 with API version 1.24.

Lets try to run this without the TLS info. 

~~~~

$ docker -H=dockerbuild.harebrained-apps.com:2376 version

Client:
 Version:      1.12.1
 API version:  1.24
 Go version:   go1.7.1
 Git commit:   6f9534c
 Built:        Thu Sep  8 10:31:18 2016
 OS/Arch:      darwin/amd64
Get http://dockerbuild.harebrained-apps.com:2376/v1.24/version: malformed HTTP response "\x15\x03\x01\x00\x02\x02".
* Are you trying to connect to a TLS-enabled daemon without TLS?

~~~~

We get an error and can't connect - docker is even so helpful as to suggest that we are trying to connect to a TLS-enabled daemon without TLS. Awesome.

We really don't want to have to send in the four tls flags every time we want to connect to our remote host - so we will put our CA and client certs and keys in a location where the Docker client can find them.

~~~~

$ mkdir -pv ~/.docker
$ cd ~/tlsBuild
$ cp -v {ca,cert,key}.pem ~/.docker

$ docker --tls -H tcp://dockerbuild.harebrained-apps.com:2376 ps -a

~~~~

As you'd expect there are no containers running / or stopped on our new install.

~~~~

$ docker -H tcp://dockerbuild.harebrained-apps.com:2376 images

~~~~

And no images. Let's fix that really quick.

~~~~

$ docker --tls -H tcp://dockerbuild.harebrained-apps.com:2376 run -d -p 80:8080 --name myJenkins jenkins

Unable to find image 'jenkins:latest' locally
latest: Pulling from library/jenkins
...

~~~~

You can see that Docker is pulling the Jenkins image to the remote host, once that is complete, we can access Jenkins at our IP or domain name: http://dockerbuild.harebrained-apps.com

Jenkins up and running in a Docker container, in a VM, in Azure. Since this isn't really the Jenkins image we want we won't start configuring it and we will clean up a bit.

~~~~

$ docker --tls -H tcp://dockerbuild.harebrained-apps.com:2376 rm -f myJenkins

~~~~

And you know just to show we *can* do things locally on the VM we will SSH in to clean up a bit more.

~~~~

$ ssh dockeruser@dockerbuild.harebrained-apps.com

$ docker rmi jenkins

$ docker images

~~~~

There all cleaned up, nice and tidy. 

### Conclusion and Next Steps
We now have docker running securely in a VM in Azure. Pretty cool and pretty simple but this is the foundation of our Automated Build system so it was important to get it setup correctly. 

In the next installment we really get to the meat of our automated build system, using our own custom images for our Jenkins master, setting up [ephemeral](https://en.wiktionary.org/wiki/ephemeral) Jenkins slave nodes; Jenkins will spin up docker containers as build environments that only get started when a build job needs them, so if you need a Java build environment or a dotnet core environment, Jenkins will start start a Docker container to handle your build! Exciting stuff! See you soon...

### Resources
Video Tutorial: [https://youtu.be/P7dGzLa4BHY](https://youtu.be/P7dGzLa4BHY)
