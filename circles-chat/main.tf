terraform {
  backend "s3" {
    bucket         = "circles-chat-terraform"
    region         = "eu-central-1"
    key            = "circles-chat-terraform.tfstate"
    dynamodb_table = "circles-chat-terraform"
    encrypt        = true
  }
}

# AWS
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.aws_region}"
}

data "aws_availability_zones" "default" {}

data "terraform_remote_state" "circles_vpc" {
  backend = "s3"
  config {
    bucket         = "circles-vpc-terraform"
    region         = "eu-central-1"
    key            = "circles-vpc-terraform.tfstate"
    dynamodb_table = "circles-vpc-terraform"
    encrypt        = true
  }
}


data "aws_acm_certificate" "chat_joincircles" {
  domain   = "chat.joincircles.net"
  statuses = ["ISSUED"]
}

## EC2
data "aws_ami" "stable_coreos" {
  most_recent = true

  filter {
    name   = "description"
    values = ["CoreOS Container Linux stable *"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["595879546273"] # CoreOS
}

### Network

variable "chat_public_cidrs" {
  default = ["10.0.0.0/26", "10.0.0.64/26"]
}

variable "chat_private_cidrs" {
  default = ["10.0.0.128/26", "10.0.0.192/26"]
}

resource "aws_subnet" "public" {
  count             = "${var.az_count}"
  vpc_id            = "${data.terraform_remote_state.circles_vpc.vpc_id}"
  cidr_block        = "${element(var.chat_public_cidrs, count.index)}"
  availability_zone = "${data.aws_availability_zones.default.names[count.index]}"

  tags {
    Name = "${var.project_prefix}-public-subnet-${count.index}"
    Environment = "${var.environment}"
    Project = "${var.project}"
  }
}


resource "aws_route_table" "default" {
  vpc_id = "${data.terraform_remote_state.circles_vpc.vpc_id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${data.terraform_remote_state.circles_vpc.igw_id}"
  }

  tags {
    Name        = "${var.project_prefix}-route-table"
    Environment = "${var.environment}"
    Project = "${var.project}"
  }
}

resource "aws_route_table_association" "default" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.default.id}"
}

### Compute

resource "aws_autoscaling_group" "chat" {
  name                 = "${var.project_prefix}-asg"
  vpc_zone_identifier  = ["${aws_subnet.public.*.id}"]
  min_size             = "${var.asg_min}"
  max_size             = "${var.asg_max}"
  desired_capacity     = "${var.asg_desired}"
  launch_configuration = "${aws_launch_configuration.chat.name}"

  tags = [
    {
      key                 = "Name"
      value               = "${var.project_prefix}-instance"
      propagate_at_launch = true
    },
    {
      key                 = "Environment"
      value               = "${var.environment}"
      propagate_at_launch = true
    },
        {
      key                 = "Project"
      value               = "${var.project}"
      propagate_at_launch = true
    }
  ]
}

data "template_file" "cloud_config" {
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    aws_region         = "${var.aws_region}"
    ecs_cluster_name   = "${aws_ecs_cluster.chat.name}"
    ecs_log_level      = "info"
    ecs_agent_version  = "latest"
    ecs_log_group_name = "${aws_cloudwatch_log_group.ecs.name}"
  }
}

# resource "aws_key_pair" "circles_chat" {
#   key_name   = "circles-chat"
#   public_key = "${file("ssh/circles-chat.pub")}"
# }

resource "aws_launch_configuration" "chat" {
  security_groups             = ["${aws_security_group.instance_sg.id}"]
  # key_name                    = "${aws_key_pair.circles_chat.key_name}"
  image_id                    = "${data.aws_ami.stable_coreos.id}"            //"ami-10e6c8fb"
  instance_type               = "t2.small"
  iam_instance_profile        = "${aws_iam_instance_profile.chat.name}"
  user_data                   = "${data.template_file.cloud_config.rendered}"
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

### Security

resource "aws_security_group" "lb_sg" {
  description = "controls access to the application ELB"

  vpc_id = "${data.terraform_remote_state.circles_vpc.vpc_id}"
  name   = "${var.project_prefix}-lb-sg"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags {
    Name        = "${var.project_prefix}-lb-sg"
    Environment = "${var.environment}"
    Project = "${var.project}"
  }
}

resource "aws_security_group" "instance_sg" {
  description = "controls direct access to application instances"
  vpc_id      = "${data.terraform_remote_state.circles_vpc.vpc_id}"
  name        = "${var.project_prefix}-inst-sg"

  ingress {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80

    security_groups = [
      "${aws_security_group.lb_sg.id}",
    ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443

    security_groups = [
      "${aws_security_group.lb_sg.id}",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${var.project_prefix}-instance-sg"
    Environment = "${var.environment}"
    Project = "${var.project}"
  }
}

## ECS

resource "aws_ecs_cluster" "chat" {
  name = "${var.project_prefix}-cluster"
}

data "template_file" "chat_task_definition" {
  template   = "${file("${path.module}/chat-task-def.json")}"
  depends_on = ["aws_alb.chat"]

  vars {
    log_group_region     = "${var.aws_region}"
    log_group_name       = "${aws_cloudwatch_log_group.chat.name}"
    mongo_password       = "${var.mongo_password}"
    mongo_oplog_password = "${var.mongo_oplog_password}"
    chat_url             = "${aws_alb.chat.dns_name}"
    smtp_host            = "${var.smtp_host}"
    smtp_username        = "${var.smtp_username}"
    smtp_password        = "${var.smtp_password}"
  }
}

resource "aws_ecs_task_definition" "chat" {
  family                = "chat-taskdef"
  container_definitions = "${data.template_file.chat_task_definition.rendered}"
}

resource "aws_ecs_service" "chat" {
  name                               = "${var.project_prefix}-ecs-service"
  cluster                            = "${aws_ecs_cluster.chat.id}"
  task_definition                    = "${aws_ecs_task_definition.chat.arn}"
  desired_count                      = "${var.asg_desired}"
  iam_role                           = "${aws_iam_role.ecs_service.name}"
  deployment_maximum_percent         = "100"
  deployment_minimum_healthy_percent = "50"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.chat.id}"
    container_name   = "chat"
    container_port   = "3000"
  }

  depends_on = [
    "aws_iam_role_policy.ecs_service",
    "aws_alb_listener.chat_http",
    "aws_alb_listener.chat_https",
  ]
}

## IAM

resource "aws_iam_role" "ecs_service" {
  name = "${var.project_prefix}-ecs-service-role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_service" {
  name = "${var.project_prefix}-ecs-policy"
  role = "${aws_iam_role.ecs_service.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "chat" {
  name = "${var.project_prefix}-instance-profile"
  role = "${aws_iam_role.instance.name}"
}

resource "aws_iam_role" "instance" {
  name = "${var.project_prefix}-instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "template_file" "instance_profile" {
  template = "${file("${path.module}/instance-profile-policy.json")}"

  vars {
    app_log_group_arn = "${aws_cloudwatch_log_group.chat.arn}"
    ecs_log_group_arn = "${aws_cloudwatch_log_group.ecs.arn}"
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "${var.project_prefix}-instance-policy"
  role   = "${aws_iam_role.instance.name}"
  policy = "${data.template_file.instance_profile.rendered}"
}

## ALB

resource "aws_alb_target_group" "chat" {
  name     = "${var.project_prefix}-alb-tg"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.circles_vpc.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

  stickiness {
    type = "lb_cookie"
  }

  tags {
    Name        = "${var.project_prefix}-alb-tg"
    Environment = "${var.environment}"
    Project = "${var.project}"
  }
}

resource "aws_alb" "chat" {
  name                       = "${var.project_prefix}-alb"
  subnets                    = ["${aws_subnet.public.*.id}"]
  security_groups            = ["${aws_security_group.lb_sg.id}"]
  enable_deletion_protection = true

  tags {
    Name        = "${var.project_prefix}-chat-alb"
    Environment = "${var.environment}"
    Project = "${var.project}"
  }
}

resource "aws_alb_listener" "chat" {
  load_balancer_arn = "${aws_alb.chat.id}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.chat_joincircles.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.chat.id}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "chat_http" {
  load_balancer_arn = "${aws_alb.chat.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.chat.id}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "chat_https" {
  load_balancer_arn = "${aws_alb.chat.id}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.chat_joincircles.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.chat.id}"
    type             = "forward"
  }
}

## CloudWatch Logs

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "${var.project_prefix}-chat-ecs"
  retention_in_days = "60"

  tags {
    Name        = "${var.project_prefix}-chat-ecs"
    Environment = "${var.environment}"
    Project = "${var.project}"
  }
}

resource "aws_cloudwatch_log_group" "chat" {
  name              = "${var.project_prefix}-chat"
  retention_in_days = "60"

  tags {
    Name        = "${var.project_prefix}-chat"
    Environment = "${var.environment}"
    Project = "${var.project}"
  }
}