---
layout: post
title: 'Automated Build System Part 3.5: Docker Registry 503 Errors'
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

A new wrinkle with the Docker registry is that when your registry storage (Azure in our case) is empty the storage health check will fail causing our Docker Registry to return 503 errors.

<!--more-->

[https://github.com/docker/distribution/issues/2292](https://github.com/docker/distribution/issues/2292) This issue talks about S3 - but the same issue applies to any empty registry storage. Looks like this [PR](https://github.com/docker/distribution/pull/2377) fixes the issue but it has not been released yet.

Here is how we've arrvied at this point:

{% include abs.md %}

So in our case here is how to fix the issue:

### Disable the health check

SSH into our VM:

```shell
ssh dockeruser@dockerbuild.harebrained-apps.com
```

Then run a shell in our docker registry container...

```shell
docker exec -it jenkins_registry_1 /bin/sh
```
edit the registry config.yml

```shell

cd /etc/docker/registry
apk update
apk add nano
nano config.yml

```

In config.yml set

```yml

health:
  storagedriver:
    enabled: false
    interval: 10s
    threshold: 3

```

Save file:
CTRL-X 
Y 
Enter

Exit from the registry container

```shell
exit
```

Back on the VM... restart the jenkins project to pick up the config changes:

```shell
docker-compose -p jenkins stop
docker-compose -p jenkins up -d nginx data master registry
```

Push an image to our private registry:

```shell

docker login dockerregistry.harebrained-apps.com
docker push dockerregistry.harebrained-apps.com/jenkins-slave

```

### Enable the health check

Once there is an image in our registry we can then re-enable the health check:

```shell

docker exec -it jenkins_registry_1 /bin/sh
cd /etc/docker/registry
nano config.yml

```

In config.yml set enabled to true

```yaml

health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3

```

Save file:
CTRL-X 
Y 
Enter

Exit from the registry container

```shell

exit

```

Restart the jenkins project to pick up the config changes

```shell

docker-compose -p jenkins stop
docker-compose -p jenkins up -d nginx data master registry

```

That should do it. You should be back in business.

