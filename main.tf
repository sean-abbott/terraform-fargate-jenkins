locals {
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
    }
  ]
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

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.name_prefix}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
# End task execution role

module "container_definition" {
  # https://github.com/cloudposse/terraform-aws-ecs-container-definition
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.23.0"

  container_name               = "${var.name_prefix}-jenkins-server"
  container_image              = "jenkins/jenkins:lts"
  container_memory             = 4096
  container_memory_reservation = 2048
  port_mappings                = local.server_td_port_mappings
  healthcheck                  = local.server_healthcheck
  container_cpu                = 2048
  essential                    = true
  environment                  = local.server_environment
  # TODO pass in log config
  #log_configuration            = var.log_configuration
  # TODO efs
  #mount_points                 = var.mount_points
  # TODO this is also a possibility if git source doesn't work
  #volumes_from                 = var.volumes_from
  # TODO this is a possibility if git source doesn't work
  #container_depends_on         = var.container_depends_on
}

# Task Definition
resource "aws_ecs_task_definition" "server" {
  family = "jenkins-server"
  # TODO looks ok, mostly just a wrapper for the map
  # https://github.com/cloudposse/terraform-aws-ecs-container-definition/blob/master/main.tf#L27
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
