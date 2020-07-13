# Terraform Fargate Jenkins
This module intends to allow you stand up Jenkins, configured by the Configuration as Code plugin, on Fargate, using nothing but terraform to deploy and update the configuration.

The intended audience is people who already have resources like network and VPCs. This is NOT intended to be someone's first terraform module.

Please note this module is experimental; as of the time of the writing of this README, I don't even know if this will work.

Some of the initial terraform for this was taken from https://github.com/cn-terraform/terraform-aws-jenkins
