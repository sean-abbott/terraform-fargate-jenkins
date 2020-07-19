# Terraform Fargate Jenkins
This module intends to allow you stand up Jenkins, configured by the Configuration as Code plugin, on Fargate, using nothing but terraform to deploy and update the configuration.

The intended audience is people who already have resources like network and VPCs. This is NOT intended to be someone's first terraform module.

Please note this module is experimental; as of the time of the writing of this README, I don't even know if this will work.

Some of the initial terraform for this was taken from https://github.com/cn-terraform/terraform-aws-jenkins


## Requirements
Some things that must be in place for this module to work correctly.
* You must use a docker image that has some requirements. See [my image](https://hub.docker.com/repository/docker/seanabbott/aws-fargate-jenkins) for an example.
* You need to have a jenkins image running that has the configuration-as-code plugin installed
* You need to have a jenkins image that is setup to pull secrets from 


### TODO
* Set up the parameter values automatically with the admin password. Could also stand to set up the URL in a separate thing on the calling side, as it needs to be in place for the CASC to work.
* More instructions
* Provide the necessary setup to let jenkins run ECS agents; at the minimum this will be adding the IAM permissions. It's on the caller to use an image with the plugin installed. See [requirements](#requirements)
* figure out and provide instructions for running container image builds in this setup. Perhaps https://github.com/Dwolla/jenkins-agent-docker-kaniko?


### Notes

Repos I leveraged inspiration from:
* https://github.com/cn-terraform/terraform-aws-ecs-alb
* https://github.com/cn-terraform/terraform-aws-jenkins
* https://fishi.devtail.io/weblog/2019/01/12/jenkins-as-code-part-2/ 
* https://github.com/cn-terraform/terraform-aws-ecs-fargate-task-definition

#### Known issues
* ECS/Fargate platform 1.4 fails this with some kind of lstat error. Seems like a bug on their end; it workins fine with 1.3
