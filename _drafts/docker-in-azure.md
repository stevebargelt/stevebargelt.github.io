---
layout: post
title: 'Docker in Azure'
subtitle: 
portfolio:  
thumbimage: ''
image: ''
author: Steve Bargelt
category: software
tags: [containers, azure, Docker]
---

### Create the VM, Resouce Group, and supporting artifacts in Azure 

In the Azure portal spin up a machine running Ubuntu 16.04 LTS or Ubuntu 14.04 LTS. For the purpose of this demo, I chose Ubuntu 16.04 LTS on a DS1_V2 sized machine and left the remaing defaults (I disabled monitoring just for this demo). 

[![alt text](/assets/dockerAzure001_small.png)](/assets/dockerAzure001.png)

You will need to use or create a public/private keypair to be able to connect to your new VM via SSH:

~~~~

ssh-keygen -t rsa -b 2048 -C "steve@dockerBlogVmAzure"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/docker_blog_id_rsa

~~~~
<script type="text/javascript" src="https://asciinema.org/a/bzynaawxgryfbqotfvzn8tefu.js" id="asciicast-bzynaawxgryfbqotfvzn8tefu" async></script>

* Create a new Resource Group (I named mine dockerBlog)
* Remember the username you entered
* Inset SSH public key

Once Azure has provisioned your new VM, set Inbound Security rules. Yes, you can set the Inbound Rules up during the initial build of the VM. It seemed a bit easier to break this out into the next step. 

In the Netowrk Security Group created by Azure (it will be named something like <nameOfResourceGroup-nsg> - mine recource group is dockerBlog and my network security group is  dockerBlog-nsg) port 22 should be open as an inbound rule; secured with the public key you provided during setup. Add the following rules to allow Docker and Jenkins to function in your environment:

* 22, ssh, TCP
* 80, http, TCP
* 2376, docker TLS, TCP
* 8080, jenkins Slaves Web, Any
* 50000, Jenkins Slaves, Any

[![alt text](/assets/dockerAzure002_small.png)](/assets/dockerAzure002.png)

Test your SSH connection to the VM and grab the local IP while you are at it: 

~~~~

ssh stevebargelt@dockerblog.westus.cloudapp.azure.com -p 22
ifconfig eth0

~~~~
<script type="text/javascript" src="https://asciinema.org/a/4r0ifabsd0pwi2dqe44w2br29.js" id="asciicast-4r0ifabsd0pwi2dqe44w2br29" async></script>

Also grab your IP address and/or DNS name from the Azure portal.
* Public IP: 40.78.67.32 
* DNS: dockerblog.westus.cloudapp.azure.com
* Private IP: 10.0.0.4

### Generate the TLS certificates

We have to generate TLS certificates to be able to use Docker remotely. The easiest way to do so is to use [this script](https://gist.github.com/sheerun/ccdeff92ea1668f3c75f) provided on GitHub. Since we want to learn how to do this the manual way, here are the steps:

{% highlight shell %}
mkdir tlsBlog
cd tlsBlog
openssl genrsa -aes256 -out ca-key.pem 4096
openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem
openssl genrsa -out server-key.pem 4096
openssl req -subj "/CN=dockerblog.westus.cloudapp.azure.com" -sha256 -new -key server-key.pem -out server.csr
{% endhighlight %}

Since the TLS connection can be made via IP address (between machines on the private network in Azure and to the public IP address from external machines) ina ddition to the DNS name, the IP addresses need to be specified when creating the certificate.

~~~~

echo subjectAltName = IP:40.78.67.32,IP:10.0.0.4,IP:127.0.0.1 > extfile.cnf
openssl x509 -req -days 365 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -extfile extfile.cnf

~~~~

For client authentication, create a client key and certificate signing request:

~~~~

openssl genrsa -out key.pem 4096
openssl req -subj '/CN=client' -new -key key.pem -out client.csr
echo extendedKeyUsage = clientAuth > extfile.cnf
openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -extfile extfile.cnf

~~~~

You can safely remove the certificate signing requests:

~~~~
rm -v client.csr server.csr
~~~~

~~~~
chmod -v 0400 ca-key.pem key.pem server-key.pem
~~~~

~~~~
chmod -v 0444 ca.pem server-cert.pem cert.pem
~~~~
<script type="text/javascript" src="https://asciinema.org/a/1kzhmqyyz2xxe9k54naxsofwq.js" id="asciicast-1kzhmqyyz2xxe9k54naxsofwq" async></script>

### Install the Docker Extensions on you VM in Azure

Once you have the TLS Keys go back the Azure portal:
	Resource group > dockerBlogVM > Extensions > Add Button > Docker (Microsoft) > Create

[![alt text](/assets/dockerAzure003_small.png)](/assets/dockerAzure003.png)

Verify that you can use TLS to send commands to your docker host in Azure:

~~~~
cd ~/tlsBlog
docker --tlsverify --tlscacert=ca.pem --tlscert=cert.pem --tlskey=key.pem -H=dockerblog.westus.cloudapp.azure.com:2376 version
~~~~
[Screencast](https://asciinema.org/a/0cn8wai9hl6985wsogjcqaj4l)

Now we move the cliet certs into the ~/.Docker folder so they are accessible and verify that we can still run Docker commands against our remote host.

~~~~

mkdir -pv ~/.docker
cd ~/tlsBlog
cp -v {ca,cert,key}.pem ~/.docker
docker --tls -H tcp://dockerblog.westus.cloudapp.azure.com:2376 info
docker --tls -H tcp://dockerblog.westus.cloudapp.azure.com:2376 images

~~~~
[Screencast](https://asciinema.org/a/8rtstnslril0ak3yy9qntkcrd)

>Warning: Anyone with the keys can give any instructions to your Docker daemon, giving them root access to the machine hosting the daemon. Guard these keys as you would a root password!

### Jenkins

In the next installmets of this series we will explore running jenkins in this Docker instance on Azure in such a way that the Jenkins Master spins up Jenkins Slaves based on the requested build. For now lets just play with Jenkins in Docker in Azure:

~~~~

docker --tls -H tcp://dockerblog.westus.cloudapp.azure.com:2376 run -d -p 8080:8080 jenkins
 
~~~~ 
<script type="text/javascript" src="https://asciinema.org/a/9ftd0o9ksu6n212vbn28c87jb.js" id="asciicast-9ftd0o9ksu6n212vbn28c87jb" async></script>

[![alt text](/assets/dockerAzure004_small.png)](/assets/dockerAzure004.png)

Of course this is just a fun Jenkins container to play with. We will be rolling our own Jenkins images over the next few blog posts in order to setup our system correctly. Once you are done playing with Jenkins in Docker in Azure you can clean up using `docker stop` `docker rm` and `docker rmi`
