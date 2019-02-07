/*====
Cloudwatch Log Group
======*/
resource "aws_cloudwatch_log_group" "circles_api" {
  name = "${var.project_prefix}-logs"

  tags {
    Application = "${var.project_prefix}"
    Environment = "${var.environment}"    
  }
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
  name = "${var.project_prefix}-ecs-cluster"
}

/*====
ECS task definitions
======*/

/* the task definition for the api service */
data "template_file" "api_task" {
  template = "${file("${path.module}/tasks/api_task_definition.json")}"

  vars {
    image                     = "${aws_ecr_repository.circles_api.repository_url}"  
    log_group_name            = "${aws_cloudwatch_log_group.circles_api.name}"
    log_group_region          = "${var.region}"
    cognito_pool_id           = "${var.cognito_pool_id}" 
    region                    = "${var.region}"
    database_name             = "${var.database_name}"
    database_user             = "${var.database_user}"
    database_host             = "${var.database_host}"
    database_password         = "${var.database_password}"
    database_port             = "${var.database_port}" 
    android_platform_gcn_arn  = "${var.android_platform_gcn_arn}"
    private_key               = "${var.private_key}"
  }
}

resource "aws_ecs_task_definition" "circles_api" {
  family                   = "circles_api"
  container_definitions    = "${data.template_file.api_task.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"
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

  tags {
    Name        = "${var.environment}-ecs-service-sg"
    Environment = "${var.environment}"
  }
}

/* Simply specify the family to find the latest ACTIVE revision in that family */
data "aws_ecs_task_definition" "circles_api" {
  depends_on = [ "aws_ecs_task_definition.circles_api" ]
  task_definition = "${aws_ecs_task_definition.circles_api.family}"
}

resource "aws_ecs_service" "circles_api" {
  name            = "${var.project_prefix}-ecs-service"
  task_definition = "${aws_ecs_task_definition.circles_api.family}:${max("${aws_ecs_task_definition.circles_api.revision}", "${data.aws_ecs_task_definition.circles_api.revision}")}"
  desired_count   = 2
  launch_type     = "FARGATE"
  cluster         = "${aws_ecs_cluster.circles_api.id}"
  depends_on      = ["aws_iam_role_policy.ecs_service_role_policy"]

  network_configuration {
    security_groups = ["${var.security_groups_ids}", "${aws_security_group.ecs_service.id}"]
    subnets         = ["${var.subnets_ids}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.circles_api.arn}"
    container_name   = "circles-api-ecr"
    container_port   = "8080"
  }

  depends_on = ["aws_alb_target_group.circles_api"]
}

/*====
App Load Balancer
======*/
resource "random_id" "target_group_sufix" {
  byte_length = 2
}

resource "aws_alb_target_group" "circles_api" {
  name     = "${var.project_prefix}-${var.environment}-alb-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }
}

/* security group for ALB */
resource "aws_security_group" "api_inbound_sg" {
  name        = "${var.project_prefix}-inbound-sg"
  description = "Allow HTTP from Anywhere into ALB"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 8080
    to_port     = 8080
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

  tags {
    Name = "${var.project_prefix}-inbound-sg"
    Environment = "${var.environment}"
  }
}

resource "aws_alb" "circles_api" {
  name            = "${var.project_prefix}-alb"
  subnets         = ["${var.public_subnet_ids}"]
  security_groups = ["${var.security_groups_ids}", "${aws_security_group.api_inbound_sg.id}"]

  tags {
    Name        = "${var.project_prefix}-alb"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_listener" "circles_api" {
  load_balancer_arn = "${aws_alb.circles_api.arn}"
  port              = "8080"
  protocol          = "HTTP"
  depends_on        = ["aws_alb_target_group.circles_api"]

  default_action {
    target_group_arn = "${aws_alb_target_group.circles_api.arn}"
    type             = "forward"
  }
}

/*
* IAM service role
*/
data "aws_iam_policy_document" "ecs_service_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
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
    effect = "Allow"
    resources = ["*"]
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress"
    ]
  }
}

/* ecs service scheduler role */
resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name   = "ecs_service_role_policy"
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
  name        = "${var.project_prefix}-ecs-service-sg"
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

  tags {
    Name        = "${var.project_prefix}-ecs-service-sg"
    Environment = "${var.environment}"
  }
}

/*====
Auto Scaling for ECS
======*/

resource "aws_iam_role" "ecs_autoscale_role" {
  name               = "${var.project_prefix}-ecs-autoscale-role"
  assume_role_policy = "${file("${path.module}/policies/ecs-autoscale-role.json")}"
}
resource "aws_iam_role_policy" "ecs_autoscale_role_policy" {
  name   = "${var.project_prefix}-ecs-autoscale-role-policy"
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
  name                    = "${var.project_prefix}-scale-up"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.circles_api.name}/${aws_ecs_service.circles_api.name}"
  scalable_dimension      = "ecs:service:DesiredCount"


  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = 1
    }
  }

  depends_on = ["aws_appautoscaling_target.circles_api"]
}

resource "aws_appautoscaling_policy" "down" {
  name                    = "${var.project_prefix}-scale-down"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.circles_api.name}/${aws_ecs_service.circles_api.name}"
  scalable_dimension      = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = -1
    }
  }

  depends_on = ["aws_appautoscaling_target.circles_api"]
}

/* metric used for auto scale */
resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name          = "${var.project_prefix}-${var.environment}-cpu-util-high"
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