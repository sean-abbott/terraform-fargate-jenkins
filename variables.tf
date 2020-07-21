# Required variables
variable "cidr_blocks" {
  description = "These are cidr blocks to allow ingress to jenkins from. Suggest limiting to your internal network"
  type        = list(string)
}

variable "jenkins_config_url" {
  description = "This can be any url that the server can access, like a github raw url"
  type        = string
}
variable "name_prefix" {
  description = "prefix for various resource names in the module"
  type        = string
}

variable "subnets_private" {
  description = "List of private subnet ids"
  type        = list(string)
}

variable "tags" {
  description = "tags to attach to resources"
  type        = map(string)
}

variable "tls_cert" {
  description = "arn for tls certificate to attach to the loadbalancer"
  type        = string
}

variable "vpc_id" {
  description = "vpc id in which to create the resources"
  type        = string
}

# Optional variables
variable "container_cpu" {
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-task-defs
  description = "(Optional) The number of cpu units to reserve for the container. This is optional for tasks using Fargate launch type and the total amount of container_cpu of all containers in a task will need to be lower than the task-level cpu value"
  default     = 2048 # 2 vCPU
}

variable "container_image" {
  description = "The image to use in for jenkins server. This image must implement a way to load values from SSM parameters if you want it to work. See the default image"
  type        = string
  default     = "seanabbott/aws-fargate-jenkins"
}

variable "container_memory" {
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-task-defs
  description = "(Optional) The amount of memory (in MiB) to allow the container to use. This is a hard limit, if the container attempts to exceed the container_memory, the container is killed. This field is optional for Fargate launch type and the total amount of container_memory of all containers in a task will need to be lower than the task memory value"
  default     = 8192 # 8 GB
}

variable "lb_security_groups" {
  description = "(Optional) Any additions security groups you want to attach to the loadbalancer"
  type        = list(string)
  default     = []
}

variable "lb_enable_deletion_protection" {
  description = "(Optional) Boolean on whether to enable deletion protection on the loadbalancer. Defaults to false"
  type        = bool
  default     = false
}

variable "lb_timeout" {
  description = "Timeout for LB in seconds"
  type        = string
  default     = "600"
}

variable "region" {
  description = "(Optional) aws region for the cloudwatch logs. Should match the VPC I expect."
  type        = string
  default     = "us-east-1"
}

variable "ssm_parameters_path" {
  description = "The base path for parameters. For instance, var.ssm_parameters_path/adminpassword. Do not use a trailing slash."
  type        = string
  default     = "/service/jenkins/secrets"
}

variable "subnets_public" {
  description = "(Optional) List of public subnet ids. Use this INSTEAD of subnets_private if you want public facing"
  type        = list(string)
  default     = []
}

variable "task_role_arn" {
  description = "(Optional) The ARN of IAM role that allows your Amazon ECS container task to make calls to other AWS services. If not specified, `aws_iam_role.ecs_task_execution_role.arn` is used"
  type        = string
  default     = null
}

variable "volumes" {
  description = "(Optional) A set of volume blocks that containers in your task may use"
  type = list(object({
    host_path = string
    name      = string
    docker_volume_configuration = list(object({
      autoprovision = bool
      driver        = string
      driver_opts   = map(string)
      labels        = map(string)
      scope         = string
    }))
    efs_volume_configuration = list(object({
      file_system_id = string
      root_directory = string
    }))
  }))
  default = []
}
