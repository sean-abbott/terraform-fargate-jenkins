#------------------------------------------------------------------------------
# AWS ECS Task Execution Role
#------------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.name_preffix}-ecs-task-execution-role"
  assume_role_policy = file("${path.module}/files/iam/ecs_task_execution_iam_role.json")
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
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
