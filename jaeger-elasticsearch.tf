resource "aws_security_group" "elasticsearch_jaeger" {
  name        = "elasticsearch-jaeger-sg"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Elasticsearch jaeger"

  tags {
    Name        = "elasticsearch-jaeger-sg"
  }
}

resource "aws_security_group_rule" "elasticsearch-jaeger-sg-rule-egress" {
  security_group_id = "${aws_security_group.elasticsearch_jaeger.id}"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "elasticsearch-jaeger-sg-rule-ingress" {
  security_group_id = "${aws_security_group.elasticsearch_jaeger.id}"
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_elasticsearch_domain" "jaeger" {
  domain_name           = "jaeger"
  elasticsearch_version = "6.3"

  cluster_config {
    instance_type  = "m4.large.elasticsearch"
    instance_count = 1
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp2"
    volume_size = 100
  }

  vpc_options {
    security_group_ids = ["${aws_security_group.elasticsearch_jaeger.id}"]
    subnet_ids         = ["${var.vpc_subnets}"]
  }

  snapshot_options {
    automated_snapshot_start_hour = 23
  }

  tags {
    Domain = "jaeger"
  }

  access_policies = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:eu-west-1:${var.account_id}:domain/jaeger/*"
    }
  ]
}
CONFIG
}

resource "aws_route53_record" "jaeger-dns" {
  zone_id = "${var.private_domain_zone_id}"
  name    = "jaeger-elasticsearch.${var.private_domain_name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_elasticsearch_domain.jaeger.endpoint}"]
}
