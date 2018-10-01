/*====
ECR repository to store our Docker images
======*/
resource "aws_ecr_repository" "circles_api" {
  name = "${var.project_prefix}-ecr"
} 

/*====
ECS service
======*/

/* Security Group for ECS */
resource "aws_security_group" "ecs_service" {
  vpc_id      = "${aws_vpc.circles_backend.id}"
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

/* Simply specify the family to find the latest ACTIVE revision in that family */
data "aws_ecs_task_definition" "circles_api" {
  task_definition = "${aws_ecs_task_definition.circles_api.family}"
}

resource "aws_ecs_service" "circles_api" {
  name            = "${var.project_prefix}-ecs-service"
  task_definition = "${aws_ecs_task_definition.circles_api.family}:${max("${aws_ecs_task_definition.circles_api.revision}", "${data.aws_ecs_task_definition.circles_api.revision}")}"
  desired_count   = 2
  launch_type     = "FARGATE"
  cluster         = "${aws_ecs_cluster.cluster.id}"
  depends_on      = ["aws_iam_role_policy.ecs_service_role_policy"]

  network_configuration {
    security_groups = ["${var.security_groups_ids}", "${aws_security_group.ecs_service.id}"]
    subnets         = ["${var.subnets_ids}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.circles_api.arn}"
    container_name   = "circles_api"
    container_port   = "80"
  }

  depends_on = ["aws_alb_target_group.circles_api"]
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

/* the task definition for the web service */
data "template_file" "api_task_definition" {
  template = "${file("api_task_definition.json")}"

  vars {
    circles_api_image = "${aws_ecr_repository.circles_api.repository_url}"
    log_group_name    = "${aws_cloudwatch_log_group.circles_api.name}"
    aws_region        = "${var.aws_region}"
    database_url      = "postgresql://${var.database_username}:${var.database_password}@${var.database_endpoint}:5432/${var.database_name}?encoding=utf8&pool=40"    
  }
}

resource "aws_ecs_task_definition" "circles_api" {
  family                   = "api_td"
  container_definitions    = "${data.template_file.api_task_definition.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.ecs_execution_role.arn}"
}