---
layout: post
title: 'Jenkins inside a Docker Container in Azure'
subtitle: 
portfolio:  
thumbimage: '/assets/azure_docker_jenkins_small.png'
image: '/assets/azure_docker_jenkins.png'
author: Steve Bargelt
category: devops
tags: [jenkins, cd, ci, docker, azure, riot games]
---

### Credit Where Credit is Due
Riot Games Engineering has been an inspiration to me for the past several years. My son is an avid League of Legends player and I've dabbled myself. I've spent many hours reading their tech blog and watching their engineers speak at conferences. I often use Riot as an example in my day job - saying things like, "well if Riot Games can do it, we certainly can!" In [January of 2014](http://www.riotgames.com/articles/20140711/1322/league-players-reach-new-heights-2014), there were over 67 million players per month; 27 million people played at least once per day and there were 7.5 million concurrent players during peak hours. Insane traffic! Yet they find a way to innovate and migrate their tech rapidly. In addition, they are consistently recognized as one of the [Best Places to Work](http://www.riotgames.com/articles/20150309/1656/riot-lands-13-fortune’s-100-best-companies-work-list).

I've been interested in containers since early 2015, but I have not had a chance to really dig in and understand Docker until recently. I watched [Docker Deep Dive](https://www.pluralsight.com/courses/docker-deep-dive) from Pluralsight, which really helped with my foundational knowledge. When I was searching for next steps, I found a link from DockerCon to this [excellent video](https://engineering.riotgames.com/news/thinking-inside-container-dockercon-talk-and-story-so-far) from Riot Games on how they have automated their build process using Jenkins in Docker containers. I love that they have pushed the responsibility for creating the container images to the dev teams.

I followed along with [Max's seven part how-to series](https://engineering.riotgames.com/news/thinking-inside-container) - including the tutorial - and was blown away. I'm finally understanding the power of containers. 

I was inspired. My current employer is using Azure (yes, we plan to use multiple cloud providers, but for now, Azure) so I wanted to translate what I was learning to run in Azure. I highly recommend following Max's posts before working through my posts. I'm going to build upon a lot of what I learned from those posts to get us set up in Azure.

### The Series 
Using Riot Games' process as inspiration here are my goals for this series:

1. Document the manual steps for each piece of the puzzle. There are scripts and shortcuts our there, but I want to understand exactly what is happening. I'll link to shortcuts, cheats, and helper scripts that I know of.
1. Provision Docker in a VM in Azure
1. Spin up Jenkins slaves from images on an as-needed basis to build software.

Posts I have planned:

1. [Running Docker in Azure - Portal]()
1. Running Docker in Azure - Azure CLI
1. Custom Jenkins Master Docker image for Azure
1. Custom Jenkins Slave Docker image(s) for Azure  
1. Using Azure Container Service 