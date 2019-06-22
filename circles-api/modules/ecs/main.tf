/*====
Cloudwatch Log Group
======*/
resource "aws_cloudwatch_log_group" "circles_api" {
  name = "${var.project}-logs"

  tags = "${merge(
    var.common_tags,
    map(
      "name", "${var.project}-logs"
    )
  )}"
}

/*====
ECR repository to store our Docker images
======*/
resource "aws_ecr_repository" "circles_api" {
  name = "${var.repository_name}"
}

/*====
ECS cluster
======*/
resource "aws_ecs_cluster" "circles_api" {
  name = "${var.project}-ecs-cluster"
}

/*====
ECS service
======*/

/* Security Group for ECS */
resource "aws_security_group" "ecs_service" {
  vpc_id      = "${var.vpc_id}"
  name        = "${var.environment}-ecs-service-sg"
  description = "Allow egress from container"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${merge(
    var.common_tags,
    map(
      "name", "${var.environment}-ecs-service-sg"
    )
  )}"
}

/*====
App Load Balancer
======*/

/* security group for ALB */
resource "aws_security_group" "api_inbound_sg" {
  name        = "${var.project}-inbound-sg"
  description = "Allow HTTPS from Anywhere into ALB"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8545
    to_port     = 8545
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${merge(
    var.common_tags,
    map(
      "name", "${var.project}-inbound-sg"
    )
  )}"
}

resource "aws_alb" "circles_api" {
  name            = "${var.project}-alb"
  subnets         = ["${var.public_subnet_ids}"]
  security_groups = ["${var.security_groups_ids}", "${aws_security_group.api_inbound_sg.id}"]

  tags = "${merge(
    var.common_tags,
    map(
      "name", "${var.project}-alb"
    )
  )}"
}

resource "random_id" "target_group_sufix" {
  byte_length = 2
  count = 2
}


resource "aws_alb_target_group" "circles_api" {
  name        = "api-${var.environment}-alb-tg-${random_id.target_group_sufix.0.hex}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = "${var.vpc_id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_alb_listener" "circles_api_http" {
  load_balancer_arn = "${aws_alb.circles_api.arn}"
  port              = "80"
  protocol          = "HTTP"
  depends_on        = ["aws_alb_target_group.circles_api"]

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "circles_api_https" {
  load_balancer_arn = "${aws_alb.circles_api.arn}"
  port              = "443"
  protocol          = "HTTPS"
  depends_on        = ["aws_alb_target_group.circles_api"]
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${var.ssl_certificate_arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.circles_api.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "ganache_http" {
  load_balancer_arn = "${aws_alb.circles_api.arn}"
  port              = "8545"
  protocol          = "HTTP"
  depends_on        = ["aws_alb_target_group.ganache"]

  default_action {
    target_group_arn = "${aws_alb_target_group.ganache.arn}"
    type             = "forward"
  }
}

# resource "aws_alb_listener" "ganache_https" {
#   load_balancer_arn = "${aws_alb.circles_api.arn}"
#   port              = "8545"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = "${var.ssl_certificate_arn}"
#   depends_on        = ["aws_alb_target_group.ganache"]

#   default_action {
#     target_group_arn = "${aws_alb_target_group.ganache.arn}"
#     type             = "forward"
#   }
# }

## ALB Target for API
resource "aws_alb_target_group" "ganache" {
  name        = "ganache-${var.environment}-alb-tg-${random_id.target_group_sufix.1.hex}"
  port = 5678
  protocol = "HTTP"
  vpc_id = "${var.vpc_id}"
  target_type = "ip"

  // deregistration_delay = 30

  # health_check {
  #   path = "/api/v1/status"
  #   healthy_threshold = 2
  #   unhealthy_threshold = 2
  #   interval = 90
  # }

  lifecycle {
    create_before_destroy = true
  }
}

/*
* IAM service role
*/
data "aws_iam_policy_document" "ecs_service_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_role" {
  name               = "ecs_role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service_role.json}"
}

data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress",
    ]
  }
}

/* ecs service scheduler role */
resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name = "ecs_service_role_policy"

  #policy = "${file("${path.module}/policies/ecs-service-role.json")}"
  policy = "${data.aws_iam_policy_document.ecs_service_policy.json}"
  role   = "${aws_iam_role.ecs_role.id}"
}

/* role that the Amazon ECS container agent and the Docker daemon can assume */
resource "aws_iam_role" "ecs_execution_role" {
  name               = "ecs_task_execution_role"
  assume_role_policy = "${file("${path.module}/policies/ecs-task-execution-role.json")}"
}

resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name   = "ecs_execution_role_policy"
  policy = "${file("${path.module}/policies/ecs-execution-role-policy.json")}"
  role   = "${aws_iam_role.ecs_execution_role.id}"
}

/*====
ECS service
======*/

/* Security Group for ECS */
resource "aws_security_group" "api_ecs_service" {
  vpc_id      = "${var.vpc_id}"
  name        = "${var.project}-ecs-service-sg"
  description = "Allow egress from container"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${merge(
    var.common_tags,
    map(
      "name", "${var.project}-ecs-service-sg"
    )
  )}"
}

/*====
Auto Scaling for ECS
======*/

resource "aws_iam_role" "ecs_autoscale_role" {
  name               = "${var.project}-ecs-autoscale-role"
  assume_role_policy = "${file("${path.module}/policies/ecs-autoscale-role.json")}"
}

resource "aws_iam_role_policy" "ecs_autoscale_role_policy" {
  name   = "${var.project}-ecs-autoscale-role-policy"
  policy = "${file("${path.module}/policies/ecs-autoscale-role-policy.json")}"
  role   = "${aws_iam_role.ecs_autoscale_role.id}"
}

resource "aws_appautoscaling_target" "circles_api" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.circles_api.name}/${aws_ecs_service.circles_api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  role_arn           = "${aws_iam_role.ecs_autoscale_role.arn}"
  min_capacity       = 1
  max_capacity       = 2
}

resource "aws_appautoscaling_policy" "up" {
  name               = "${var.project}-scale-up"
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.circles_api.name}/${aws_ecs_service.circles_api.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }

  depends_on = ["aws_appautoscaling_target.circles_api"]
}

resource "aws_appautoscaling_policy" "down" {
  name               = "${var.project}-scale-down"
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.circles_api.name}/${aws_ecs_service.circles_api.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = -1
    }
  }

  depends_on = ["aws_appautoscaling_target.circles_api"]
}

/* metric used for auto scale */
resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name          = "${var.project}-${var.environment}-cpu-util-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "85"

  dimensions {
    ClusterName = "${aws_ecs_cluster.circles_api.name}"
    ServiceName = "${aws_ecs_service.circles_api.name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.up.arn}"]
  ok_actions    = ["${aws_appautoscaling_policy.down.arn}"]
}
