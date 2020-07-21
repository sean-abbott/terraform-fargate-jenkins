locals {
  container_name = "${var.name_prefix}-jenkins-server"
  lb_private     = length(var.subnets_private) > 0 ? true : false
  lb_subnet_ids  = length(var.subnets_private) > 0 ? var.subnets_private : var.subnets_public
  server_healthcheck = {
    command     = ["CMD-SHELL", "curl -f http://localhost:8080 || exit 1"]
    retries     = 3
    timeout     = 5
    interval    = 30
    startPeriod = 120
  }
  server_td_port_mappings = [
    {
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    },
    {
      containerPort = 50000
      hostPort      = 50000
      protocol      = "tcp"
    }
  ]
  server_environment = [
    {
      name  = "CASC_JENKINS_CONFIG",
      value = var.jenkins_config_url
    },
    {
      name  = "SECRETS",
      value = "/var/jenkins_home/secrets"
    },
    {
      name  = "JENKINS_PARAMETER_PATH",
      value = "${var.ssm_parameters_path}/secrets"
    },
  ]
}

data "aws_caller_identity" "current" {}

#------------------------------------------------------------------------------
# AWS Cloudwatch Logs
#------------------------------------------------------------------------------
module aws_cw_logs {
  source  = "cn-terraform/cloudwatch-logs/aws"
  version = "1.0.6"

  logs_path = "/ecs/service/${var.name_prefix}-server"
}

#------------------------------------------------------------------------------
# AWS ECS Task Execution Role
#------------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ssm_read" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParametersByPath"
    ]

    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameters_path}*"
    ]
  }
}

resource "aws_iam_policy" "ssm_read" {
  name   = "${var.name_prefix}-ssm-read"
  path   = "/"
  policy = data.aws_iam_policy_document.ssm_read.json
}

resource "aws_iam_role_policy_attachment" "ssm_read" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ssm_read.arn
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.name_prefix}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_control" {
  statement {
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:ListClusters",
      "ecs:DescribeContainerInstances",
      "ecs:ListTaskDefinitions",
      "ecs:DescribeTaskDefinition",
      "ecs:DeregisterTaskDefinition",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ecs:ListContainerInstances"
    ]
    resources = [
      aws_ecs_cluster.cluster.arn
    ]
  }

  statement {
    actions = [
      "ecs:RunTask",
      "ecs:StopTask",
      "ecs:DescribeTasks",
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:task-definition/*"
    ]
    condition {
      test     = "ArnEquals"
      variable = "ecs:Cluster"
      values = [
        aws_ecs_cluster.cluster.arn
      ]
    }
  }
}

resource "aws_iam_policy" "ecs_control" {
  name   = "${var.name_prefix}-ecs-control"
  path   = "/"
  policy = data.aws_iam_policy_document.ecs_control.json
}

resource "aws_iam_role_policy_attachment" "ecs_control" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_control.arn
}


# End task execution role

module "container_definition" {
  # https://github.com/cloudposse/terraform-aws-ecs-container-definition
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.23.0"

  container_name               = local.container_name
  container_image              = var.container_image
  container_memory             = 4096
  container_memory_reservation = 2048
  port_mappings                = local.server_td_port_mappings
  healthcheck                  = local.server_healthcheck
  container_cpu                = 2048
  essential                    = true
  environment                  = local.server_environment
  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = var.region
      "awslogs-group"         = module.aws_cw_logs.logs_path
      "awslogs-stream-prefix" = "ecs"
    }
    secretOptions = null
  }
  # TODO efs
  #mount_points                 = var.mount_points
  # TODO this is also a possibility if git source doesn't work
  #volumes_from                 = var.volumes_from
  # TODO this is a possibility if git source doesn't work
  #container_depends_on         = var.container_depends_on
}

# Task Definition
resource "aws_ecs_task_definition" "server" {
  family                = "jenkins-server"
  container_definitions = "[ ${module.container_definition.json_map} ]" # TODO
  task_role_arn         = var.task_role_arn == null ? aws_iam_role.ecs_task_execution_role.arn : var.task_role_arn
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  network_mode          = "awsvpc"

  # Origin has this, but I don't think we need the complexity right now
  #  dynamic "placement_constraints" {
  #    for_each = var.placement_constraints
  #    content {
  #      expression = lookup(placement_constraints.value, "expression", null)
  #      type       = placement_constraints.value.type
  #    }
  #  }
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  requires_compatibilities = ["FARGATE"]
  # Origin has this, but I don't think we need the complexity right now
  # This is for app mesh
  #  dynamic "proxy_configuration" {
  #    for_each = var.proxy_configuration
  #    content {
  #      container_name = proxy_configuration.value.container_name
  #      properties     = lookup(proxy_configuration.value, "properties", null)
  #      type           = lookup(proxy_configuration.value, "type", null)
  #    }
  #  }

  # TODO go through the volume setup and see what we can leverage
  dynamic "volume" {
    for_each = var.volumes
    content {
      name = volume.value.name

      host_path = lookup(volume.value, "host_path", null)

      dynamic "docker_volume_configuration" {
        for_each = lookup(volume.value, "docker_volume_configuration", [])
        content {
          autoprovision = lookup(docker_volume_configuration.value, "autoprovision", null)
          driver        = lookup(docker_volume_configuration.value, "driver", null)
          driver_opts   = lookup(docker_volume_configuration.value, "driver_opts", null)
          labels        = lookup(docker_volume_configuration.value, "labels", null)
          scope         = lookup(docker_volume_configuration.value, "scope", null)
        }
      }

      dynamic "efs_volume_configuration" {
        for_each = lookup(volume.value, "efs_volume_configuration", [])
        content {
          file_system_id = lookup(efs_volume_configuration.value, "file_system_id", null)
          root_directory = lookup(efs_volume_configuration.value, "root_directory", null)
        }
      }
    }
  }
}

resource "aws_security_group" "sg_worker_id" {
  name   = "${var.name_prefix}-jenkins-worker-id"
  vpc_id = var.vpc_id
  tags   = var.tags
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.name_prefix}-jenkins"
}

module ecs-fargate-service {
  source  = "cn-terraform/ecs-fargate-service/aws"
  version = "2.0.4"

  name_preffix                      = "${var.name_prefix}-jenkins"
  vpc_id                            = var.vpc_id
  ecs_cluster_arn                   = aws_ecs_cluster.cluster.arn
  health_check_grace_period_seconds = 120
  task_definition_arn               = aws_ecs_task_definition.server.arn
  private_subnets                   = var.subnets_private
  public_subnets                    = var.subnets_public
  container_name                    = local.container_name
  ecs_cluster_name                  = aws_ecs_cluster.cluster.name
  lb_arn                            = aws_lb.lb.arn
  lb_http_tgs_arns                  = [aws_lb_target_group.jenkins_http.arn, aws_lb_target_group.jenkins_jnlp.arn]
  lb_https_tgs_arns                 = []
  lb_http_listeners_arns            = [aws_lb_listener.http.arn, aws_lb_listener.jnlp.arn]
  lb_https_listeners_arns           = [aws_lb_listener.https.arn]
  load_balancer_sg_id               = aws_security_group.loadbalancer_id.id
  platform_version                  = "1.3.0"
}
