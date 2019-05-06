resource "aws_lb" "jaeger_query" {
  name     = "jaeger-collector-nlb"
  internal = true
  subnets  = ["${var.vpc_subnets}"]

  enable_deletion_protection = false
}

resource "aws_alb_target_group" "jaeger_query" {
  name                 = "jaeger-query-tg"
  deregistration_delay = 10
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = "${var.vpc_id}"

  health_check {
    protocol            = "TCP"
    port                = 16686
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_alb_listener_rule" "jaeger_query" {
  load_balancer_arn = "${aws_lb.jaeger_query.arn}"
  port              = 16686
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.jaeger_query.arn}"
  }
}

resource "aws_route53_record" "jaeger_query" {
  zone_id = "${var.private_domain_zone_id}"
  name    = "jaeger-query.${var.private_domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_lb.jaeger_query.dns_name}"
    zone_id                = "${aws_lb.jaeger_query.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_ecs_task_definition" "jaeger_query" {
  family                = "jaeger-query"
  container_definitions = "${file("${path.module}/task-definitions/jaeger-query.json")}"
  task_role_arn         = "${aws_iam_role.jaeger_agent.arn}"
}

resource "aws_ecs_service" "jaeger_query" {
  name            = "jaeger-query"
  cluster         = "${var.cluster_name}"
  task_definition = "${aws_ecs_task_definition.jaeger_query.arn}"
  desired_count   = "2"

  deployment_maximum_percent         = "100"
  deployment_minimum_healthy_percent = "50"

  load_balancer = {
    target_group_arn = "${aws_alb_target_group.jaeger_query.arn}"
    container_name   = "application"
    container_port   = "16686"
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
