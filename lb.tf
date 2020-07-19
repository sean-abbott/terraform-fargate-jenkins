resource "aws_lb" "lb" {
  name         = var.name_prefix
  subnets      = local.lb_subnet_ids
  internal     = local.lb_private
  idle_timeout = var.lb_timeout

  security_groups = concat(
    var.lb_security_groups,
    [
      aws_security_group.loadbalancer_id.id,
      aws_security_group.http.id,
      aws_security_group.jnlp.id,
    ]
  )

  enable_deletion_protection = var.lb_enable_deletion_protection

  tags = var.tags
}

resource "aws_lb_target_group" "jenkins_http" {
  name        = "${var.name_prefix}-http"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled  = true
    path     = "/login"
    port     = 8080
    protocol = "HTTP"
    matcher  = "200,302"
  }

  tags = var.tags
}

resource "aws_lb_target_group" "jenkins_jnlp" {
  name        = "${var.name_prefix}-jnlp"
  port        = 50000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  # do we need a health check for this?
  # TODO check if 5000 responds to / with 200
  tags = var.tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.lb.arn

  port            = 443
  protocol        = "HTTPS"
  ssl_policy      = "ELBSecurityPolicy-FS-2018-06"
  certificate_arn = var.tls_cert

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_http.arn
  }

}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.lb.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "jnlp" {
  load_balancer_arn = aws_lb.lb.arn

  port     = 50000
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.jenkins_jnlp.arn
    type             = "forward"
  }
}

resource "aws_security_group" "loadbalancer_id" {
  name   = "${var.name_prefix}-lb-id"
  vpc_id = var.vpc_id
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-lb-id"
  })
}

resource "aws_security_group" "jnlp" {
  name   = "${var.name_prefix}-jnlp"
  vpc_id = var.vpc_id
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jnlp-lb"
  })

  ingress {
    from_port = 50000
    to_port   = 50000
    protocol  = "tcp"
    # TODO make this security group
    security_groups = [aws_security_group.sg_worker_id.id]
  }
}

resource "aws_security_group" "http" {
  name   = "${var.name_prefix}-lb"
  vpc_id = var.vpc_id
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-lb-id"
  })

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.cidr_blocks
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.cidr_blocks
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


}
