---
layout: post
title: 'abs-04-scripting-jenkins'
subtitle: 
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
Welcome to part four of my series where we are creating an Automated Build System with Docker and Jenkins in Azure. In this installment we will be adding two scripts to Jenkins to extend its out of the box API functionality. 
<!--more-->
One of the major outcomes from this project is to allow dev teams to create their own build environments and build pipelines. The actual build job and pipeline creation is fairly straight-forward to automate using the Jenkins API. There are two pieces of our system that the default Jenkins API can't do for us. One is to create our Docker template - that piece of Jenkins config that, among other things, hooks a build label to a Docker image for a given build job. We need a mechanism to create that template. We also need to make sure that our build team is using a unique label for their build job. 

### Scripting Jenkins with Scriptler
These are two things that we can easily accomplish with the [Scriptler](https://wiki.jenkins-ci.org/display/JENKINS/Scriptler+Plugin) plugin for Jenkins and some Groovy script. If you used the jenkins-master image from the repo at [github.com/stevebargelt/jenkinsDocker](https://github.com/stevebargelt/jenkisnDocker) then the Scriptler plugin is already installed in Jenkins.  

### Get Labels
Why do we need a unique label for our each Docker Template? We want each dev team to create their own Docker images for their build environments. Jenkins needs to link that image to a particular build job. We do that through the use of a build label. My teams have decided on the following naming convention for build labels:
team name - major technology - version - minor technology - version --- minor technologies are optional and multiple minor technologies and versions allowed. A few examples:

* stars-aspnetcore-1.1
* stars-aspnetcore-1.1-efcore-1.1-reactjs-15.4.1
* hawks-jdk-1.8
* harbingers-nodejs-7.2.1
* rotfl-golang-1.8-mux-echo

So when a build with the label of `stars-aspnetcore-1.1-efcore-1.1-reactjs-15.4.1` kicks off we need to know which Docker image to pull. If multiple Docker templates are using the same label we will get inconsistent results. 

> NOTE: Initially we did allow teams to use a build image for multiple projects. Unfortunately we learned that this is something to avoid. If a build image changes for one project you can bet it will break any other projects using that image. So we now enforce having a build image specific to each piece of software. As of this tutorial we are not enforcing unique Docker images for each build job but I have planned an addition to the series to cover that topic.

The first script we will add to Scriptler will allow us to get all of the labels that have been configured (and in the next installment we will write Go code to ensure uniqueness). 

In the browser:

1. Go to Jenkins
1. Click Scriptler
1. Click Add Script
1. ID = getLabels.Groovy
1. Name = getLabels

~~~~

ssh absadmin@abs.harebrained-apps.com
cd jenkinsDocker
cd jenkinsScriptler
cat getLabels.Groovy

~~~~

Copy and paste the contents of getLabels.groovy into the Jenkins interface
Click Submit

Click on the Edit button
Click the checkbox next to Define script parameters
Name: cloudName
Click Submit

### Creating the Docker Template
The second script we need to add allows us to create the Docker template with an API call. If you remeber back to Part 2 the Docker template is the configuration that "hooks" a label to a Docker image.

Click Add Script
ID = createDockerTemplate.groovy
Name = createDockerTemplate

Back to your SSH term...

~~~~

cat getLabels.Groovy

~~~~
Copy and paste the content of createDockerTemplate.groovy into the Jenkins interface
Click Submit

Click on the Edit button
Click the checkbox next to Define script parameters
Name: cloudName
Click Add parameters
Name: label
Click Add parameters
Name: image
Click Submit

### Testing with Postman
We can use Postman or Fidler or even curl to test our work. I'll walk through the steps to test with Postman. You can get the free version of Postman at [https://www.getpostman.com/](https://www.getpostman.com/).

In Postman Click the + to create a new tab (CMD-T)

The URL to the scripts will be your domain + /scriptler/run/<ScriptName> so in my case for GetLabels 

https://dockerbuild.harebrained-apps.com/scriptler/run/getLabels.groovy

Enter the URL into the large text box
Click Params
Key: cloudName
Value: AzureCloud
Click Authorization
Enter your Jenkins Username and Password
Click Update Request
Now you can click Send
You should see the results... if you've strictly followed along you should see one label returned "testslave"

Next lets test creating a template

My URL is https://dockerbuild.harebrained-apps.com/scriptler/run/createDockerTemplate.groovy

Enter the URL into the large text box
Click Params
Key: cloudName
Value: AzureCloud
Key: label
Value: testlabel2
Key: image
Value: jenkins-slave

Click Authorization
Enter your Jenkins Username and Password
Click Update Request
Now you can click Send

If we go back to Jenkins
Manage Jenkins
Configure System
Scroll down we can see the new Docker Template has been created

### Conclusion
Thanks for watching part four of my automated build system tutorial today we've added to the API functionality of Jenkins with groovy scripts and the Scriptler plugin. 

In the next installment of this tutorial we will create the custom Go application Dockhand. Dockhand is the application that developers will interact with to self-serve thier builds. It is the yearn that weaves all of the other parts of the system together. 

[![](/assets/-small.png){: .img-responsive }](/assets/.png){: .img-blog }
[![](/assets/-small.png){: .img-responsive }](/assets/.png){: .img-blog }
[![](/assets/-small.png){: .img-responsive }](/assets/.png){: .img-blog }
[![](/assets/-small.png){: .img-responsive }](/assets/.png){: .img-blog }
