resource "aws_cloudwatch_log_group" "jaeger_agent" {
  name              = "jaeger-agent"
  retention_in_days = 30
}

resource "aws_iam_role" "jaeger_agent" {
  name = "jaeger-agent-role"

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

resource "aws_ecs_task_definition" "jaeger_agent" {
  family                = "jaeger-agent"
  container_definitions = "${file("${path.module}/task-definitions/jaeger-agent.json")}"
  task_role_arn         = "${aws_iam_role.jaeger_agent.arn}"
}

resource "aws_ecs_service" "jaeger_agent" {
  name                = "jaeger-agent"
  cluster             = "${var.cluster_name}"
  task_definition     = "${aws_ecs_task_definition.jaeger_agent.arn}"
  scheduling_strategy = "DAEMON"
  lifecycle {
    ignore_changes = ["task_definition"]
  }
}
