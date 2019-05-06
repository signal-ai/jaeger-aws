resource "aws_lb" "jaeger_collector" {
  name               = "jaeger-collector-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = ["${var.vpc_subnets}"]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "jaeger_collector" {
  name        = "jaeger-collector-tg"
  port        = 14267
  protocol    = "TCP"
  vpc_id      = "${var.vpc_id}"
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    port                = 14269
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "jaeger_collector" {
  load_balancer_arn = "${aws_lb.jaeger_collector.arn}"
  port              = 14267
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.jaeger_collector.arn}"
  }
}

resource "aws_route53_record" "jaeger_collector" {
  zone_id = "${var.private_domain_zone_id}"
  name    = "jaeger-collector.${var.private_domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_lb.jaeger_collector.dns_name}"
    zone_id                = "${aws_lb.jaeger_collector.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_iam_role" "jaeger_collector" {
  name = "jaeger-collector-role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
    "Action": "sts:AssumeRole",
    "Principal": {
      "Service": "ecs-tasks.amazonaws.com"
    },
    "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_ecs_task_definition" "jaeger_collector" {
  family                = "jaeger-collector"
  container_definitions = "${file("${path.module}/task-definitions/jaeger-collector.json")}"
  task_role_arn         = "${aws_iam_role.jaeger_collector.arn}"
  network_mode          = "awsvpc"
}

resource "aws_cloudwatch_log_group" "jaeger_collector" {
  name              = "jaeger-collector"
  retention_in_days = 30
}

resource "aws_ecs_service" "jaeger_collector" {
  name            = "jaeger-collector"
  cluster         = "${var.cluster_name}"
  task_definition = "${aws_ecs_task_definition.jaeger_collector.arn}"
  desired_count   = "3"

  deployment_maximum_percent         = "100"
  deployment_minimum_healthy_percent = "50"

  load_balancer = {
    target_group_arn = "${aws_lb_target_group.jaeger_collector.arn}"
    container_name   = "application"
    container_port   = "14267"
  }

  network_configuration {
    subnets = ["${var.vpc_subnets}"]

    security_groups = ["${aws_security_group.jaeger_collector_nlb.id}"]
  }

  launch_type = "EC2"

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  lifecycle {
    ignore_changes = ["task_definition"]
  }
}

resource "aws_security_group" "jaeger_collector_nlb" {
  name   = "jaeger-collector-sg"
  vpc_id = "${var.vpc_id}"
}

resource "aws_security_group_rule" "jaeger_collector_nlb_egress" {
  security_group_id = "${aws_security_group.jaeger_collector_nlb.id}"
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0/16"]
}

resource "aws_security_group_rule" "jaeger_collector_nlb_ingress" {
  security_group_id = "${aws_security_group.jaeger_collector_nlb.id}"
  type              = "ingress"
  from_port         = 14267
  to_port           = 14269
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0/16"]
}
