---
layout: post
title: 'Automated Build System (ABS) Part 0: Intro and Goals'
subtitle: 
portfolio:  
thumbimage: '/assets/azure_docker_jenkins_small.png'
image: '/assets/azure_docker_jenkins.png'
author: Steve Bargelt
category: devops
tags: [jenkins, cd, ci, docker, azure, riot games]
---

### Background and Credit Where Credit is Due
Riot Games Engineering has been an inspiration to me for the past several years. My son is an avid League of Legends player and I've dabbled myself. I've spent many hours reading their tech blog and watching their engineers speak at conferences. I often use Riot as an example in my day job - saying things like, "well if Riot Games can do it, we certainly can!" In [January of 2014](http://www.riotgames.com/articles/20140711/1322/league-players-reach-new-heights-2014), there were over 67 million players per month; 27 million people played at least once per day and there were 7.5 million concurrent players during peak hours. Insane traffic! Yet they find a way to innovate and migrate their tech rapidly. In addition, they are consistently recognized as one of the [Best Places to Work](http://www.riotgames.com/articles/20150309/1656/riot-lands-13-fortune’s-100-best-companies-work-list).

I've been interested in containers since early 2015, but I have not had time to really dig in and understand Docker until recently. I watched [Docker Deep Dive](https://www.pluralsight.com/courses/docker-deep-dive) from Pluralsight, which really helped with my foundational knowledge. When I was searching for next steps, I found a link from DockerCon 2016 to this [excellent video](https://engineering.riotgames.com/news/thinking-inside-container-dockercon-talk-and-story-so-far) from Maxfield Stewart of Riot Games on how his team has automated their build process using Jenkins and Docker containers. I love that they have pushed the responsibility for creating the container images to the dev teams.

I followed along with [Max's seven part how-to series](https://engineering.riotgames.com/news/thinking-inside-container) - including the tutorial - and was blown away. I was inspired! I wanted to take this system to production, in Azure. So this tutorial series was born.

So a huge thanks to Riot Game and Maxfield Stewart. Also, thank you for your interest in my Automated Build System tutorials. 

I want to quickly lay out the goals, outcomes  and expectations for these tutorials. I hate wasting time so I'll keep this is As brief as possible while still trying to give you an overview of what we are trying to accomplish here. Here is the video introduction:

<iframe width="560" height="315" src="https://www.youtube.com/embed/2E89a7Twxh8" frameborder="0" allowfullscreen></iframe>
<br/>

### Outcomes

The outcomes or user stories. I approached this from two roles... 

>As a build engineer I don't want to process tickets to create build environments, build jobs, or CI/CD pipelines for software teams so that I have time to concentrate on keeping our build infrastructure healthy and have time to research and implement forward-thinking solutions for software teams to utilize. 

>As a software developer I want to control my own build environments by creating my own build jobs and CI/CD pipelines so that I can control the flow of the software I write from my machine all the way through to production without impediments like having to open a ticket or rely on other teams. 

We will accomplish both of these outcomes and when we are done the process will look something like this:

* software developer (or team) creates a Docker image for the build environment (and presumably uses it locally). 
* Dev writes tests and code. 
* Dev adds a text file to code repository that contains the Jenkins pipleline script. 
* Dev pushes the image to the organization's private Docker registry. 
* Dev then uses a tool (currently command line that I've dubbed Dockhand) to create the buildjob/CI/CD pipeline. 
  
So with a command like: 

~~~~
dockhand --dockertlsfolder /superSecret/tlsCerts/ -registryuser dockerUser -registrypassword correcthorsebatteystaple -imagename dockerbuild.harebrained-apps.com/jenkins-slavedotnet -label TeamBargelt_DotNetCore_simpleDotNet -jenkinsurl http://dockerbuild.harebrained-apps.com -jenkinsuser stevebargelt -jenkinspassword correcthorsebatteystaple -repourl https://github.com/stevebargelt/simpleDotNet.git
~~~~

All of this happens:

* Docker image of the build environment is pulled to Docker host
* Docker container created and started
	* Test performed on Docker container 
	* Actually runs and exits properly
	* Conforms to standards
* Jenkins Docker Template is created
* Jenkins Job is created

A complete CI/CD build pipeline/environment/process is created, no intervention by a build team or any other infrastructure team. Software development teams are responsible for everything (except, of course, maintaining the infrastructure that these process run on). Pretty cool, yeah?

### What will we create?

We will create this entire automated build system step-by-step, from scratch, using Docker, Jenkins, Azure, and Go (lang) We'll even use some dotnet (core!) as our sample application under development just to mix things up. 

* Setup Docker in Azure (and connect securely from a remote machine)
* Run Jenkins in Docker… in Azure 
* Setup Jenkins to spin up ephemeral (short-lived Docker containers) for Jenkins slaves
* Setup a Docker registry/repository in Azure (including getting SSL certs)
* Explore all the Dockhand code (Go) to allow hands-off build job creation
* Walk through creating a small sample software project utilizing this system

I tried to make these tutorials as real-world as possible. I was frustrated when seeking out how-tos and tutorials. They always seemed to be incomplete or missing key pieces that would actually allow the solution to work! I can't tell you how many times I saw or heard "here's how to setup <THIS new spiffy technology> BUT that whole security thing is _hard_ so we will leave that up to you to figure out." Well, thanks for nothing! Setting systems up correctly and securely is the HARD part and that's why I was seeking out advice and examples in the first damned place! 

[![alt text](/assets/buildSysInto00_small.png)](/assets/buildSysInto00.png)

### What to expect

I will provide both videos and step-by-step written blog posts every piece of the system. I love watching a video to get a concept but hate having to scrub through a video to find one small piece of information. In addition I realize individuals learn in different ways so I want to provide as much coverage as I can about each topic.

Currently I have six installments planned to get this system up and functional with several more follow-ups to enhance or streamline the system. planned

I also vow to keep the fluff to a minimum. The intro to each video tutorial will remain under 30 seconds. I will avoid using slides (except for this intro) and I'll get to the topic and stay on topic for the entire tutorial. There will be no history lessons here; I'm not going to explain Docker, why containers are great, or why you should be ditching on-prem solutions and utilizing the cloud. I'm not going to debate Azure vs AWS vs GCS or any other technology choices. These will be to-the-point tutorials meant to help you get this automated build system up and running. If you can't tell from my choice, I'm pretty technology agnostic. I like to use what works. 

### What not to expect 
Please do understand that I am not an expert in any technology or concept in this series I am learning along the way, as a matter of fact, that's how this all started; i was taking notes as I setup this system and decided I wanted to share that knowledge. I want to get better and hone this system so in that vein I welcome comments and all of the code I write for this series will be available as open source on github. I welcome PRs, issues, and comments.

### Resources 
[Slides at SlideShare.com](http://www.slideshare.net/SteveBargelt/automated-build-system-with-docker-jenkins-and-azure-intro)

[Link to the Video](https://youtu.be/2E89a7Twxh8)


