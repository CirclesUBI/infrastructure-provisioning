# AWS
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.aws_region}"
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

data "aws_availability_zones" "available" {}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"

  tags {
    Name        = "${var.project_prefix}-vpc"
    Environment = "${var.environment}"
  }
}

resource "aws_subnet" "public" {
  count             = "${var.az_count}"
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${cidrsubnet(aws_vpc.default.cidr_block, 8, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

  tags {
    Name = "${var.project_prefix}-public-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"

  tags {
    Name        = "${var.project_prefix}-internet-gateway"
    Environment = "${var.environment}"
  }
}

resource "aws_route_table" "default" {
  vpc_id = "${aws_vpc.default.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }
}

resource "aws_route_table_association" "default" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.default.id}"
}

### Compute

resource "aws_autoscaling_group" "rocketchat" {
  name                 = "rocketchat-asg"
  vpc_zone_identifier  = ["${aws_subnet.public.*.id}"]
  min_size             = "${var.asg_min}"
  max_size             = "${var.asg_max}"
  desired_capacity     = "${var.asg_desired}"
  launch_configuration = "${aws_launch_configuration.rocketchat.name}"

  tags = [
    {
      key                 = "Name"
      value               = "rocketchat-instance"
      propagate_at_launch = true
    },
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    },
  ]
}

data "template_file" "cloud_config" {
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    aws_region         = "${var.aws_region}"
    ecs_cluster_name   = "${aws_ecs_cluster.rocketchat.name}"
    ecs_log_level      = "info"
    ecs_agent_version  = "latest"
    ecs_log_group_name = "${aws_cloudwatch_log_group.ecs.name}"
  }
}

resource "aws_key_pair" "circles_rocketchat" {
  key_name   = "circles-rocketchat"
  public_key = "${file("ssh/circles-rocketchat.pub")}"
}

resource "aws_launch_configuration" "rocketchat" {
  security_groups             = ["${aws_security_group.instance_sg.id}"]
  key_name                    = "${aws_key_pair.circles_rocketchat.key_name}"
  image_id                    = "${data.aws_ami.stable_coreos.id}"            //"ami-10e6c8fb"
  instance_type               = "t2.small"
  iam_instance_profile        = "${aws_iam_instance_profile.rocketchat.name}"
  user_data                   = "${data.template_file.cloud_config.rendered}"
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

### Security

resource "aws_security_group" "lb_sg" {
  description = "controls access to the application ELB"

  vpc_id = "${aws_vpc.default.id}"
  name   = "circles-rocketchat-lbsg"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
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
  }
}

resource "aws_security_group" "instance_sg" {
  description = "controls direct access to application instances"
  vpc_id      = "${aws_vpc.default.id}"
  name        = "circles-rocketchat-instsg"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]

    # cidr_blocks = [
    #   "${var.admin_cidr_ingress}",
    # ]
  }

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
    from_port = 8081
    to_port   = 8081

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
  }
}

## ECS

resource "aws_ecs_cluster" "rocketchat" {
  name = "rocketchat-cluster"
}

data "template_file" "rc_task_definition" {
  template   = "${file("${path.module}/rocketchat-task-def.json")}"
  depends_on = ["aws_alb.rocketchat"]

  vars {
    log_group_region     = "${var.aws_region}"
    log_group_name       = "${aws_cloudwatch_log_group.rocketchat.name}"
    mongo_password       = "${var.mongo_password}"
    mongo_oplog_password = "${var.mongo_oplog_password}"
    rocketchat_url       = "${aws_alb.rocketchat.dns_name}"
    smtp_host            = "${var.smtp_host}"
    smtp_username        = "${var.smtp_username}"
    smtp_password        = "${var.smtp_password}"
  }
}

data "template_file" "ubibot_task_definition" {
  template   = "${file("${path.module}/ubibot-task-def.json")}"
  depends_on = ["aws_ecs_service.rocketchat", "aws_alb.rocketchat"]

  vars {
    log_group_region = "${var.aws_region}"
    log_group_name   = "${aws_cloudwatch_log_group.rocketchat.name}"
    rocketchat_url   = "${aws_alb.rocketchat.dns_name}"
    ubibot_password  = "${var.ubibot_password}"
  }
}

resource "aws_ecs_task_definition" "rocketchat" {
  family                = "rocketchat-td"
  container_definitions = "${data.template_file.rc_task_definition.rendered}"
}

resource "aws_ecs_task_definition" "ubibot" {
  family                = "ubibot-td"
  container_definitions = "${data.template_file.ubibot_task_definition.rendered}"

  volume {
    name      = "redis"
    host_path = "/data/redis"
  }
}

resource "aws_ecs_service" "rocketchat" {
  name            = "rocketchat-ecs-service"
  cluster         = "${aws_ecs_cluster.rocketchat.id}"
  task_definition = "${aws_ecs_task_definition.rocketchat.arn}"
  desired_count   = "${var.asg_desired}"
  iam_role        = "${aws_iam_role.ecs_service.name}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.rocketchat.id}"
    container_name   = "rocketchat"
    container_port   = "3000"
  }

  depends_on = [
    "aws_iam_role_policy.ecs_service",
    "aws_alb_listener.rocketchat",
  ]
}

resource "aws_ecs_service" "ubibot" {
  name            = "ubibot-ecs-service"
  cluster         = "${aws_ecs_cluster.rocketchat.id}"
  task_definition = "${aws_ecs_task_definition.ubibot.arn}"
  desired_count   = 1

  depends_on = [
    "aws_iam_role_policy.ecs_service",
    "aws_alb_listener.rocketchat",
    "aws_ecs_service.rocketchat",
  ]
}

## IAM

resource "aws_iam_role" "ecs_service" {
  name = "rocketchat-ecs-service-role"

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
  name = "rocketchat-ecs-policy"
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

resource "aws_iam_instance_profile" "rocketchat" {
  name = "rocketchat-instance-profile"
  role = "${aws_iam_role.instance.name}"
}

resource "aws_iam_role" "instance" {
  name = "rocketchat-instance-role"

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
    app_log_group_arn = "${aws_cloudwatch_log_group.rocketchat.arn}"
    ecs_log_group_arn = "${aws_cloudwatch_log_group.ecs.arn}"
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "rocketchat-instance-policy"
  role   = "${aws_iam_role.instance.name}"
  policy = "${data.template_file.instance_profile.rendered}"
}

## ALB

resource "aws_alb_target_group" "rocketchat" {
  name     = "rocketchat-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.default.id}"

  tags {
    Name        = "${var.project_prefix}-rocketchat-alb-tg"
    Environment = "${var.environment}"
  }
}

resource "aws_alb" "rocketchat" {
  name            = "rocketchat-alb"
  subnets         = ["${aws_subnet.public.*.id}"]
  security_groups = ["${aws_security_group.lb_sg.id}"]

  tags {
    Name        = "${var.project_prefix}-rocketchat-alb"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_listener" "rocketchat" {
  load_balancer_arn = "${aws_alb.rocketchat.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.rocketchat.id}"
    type             = "forward"
  }
}

## CloudWatch Logs

resource "aws_cloudwatch_log_group" "ecs" {
  name = "${var.project_prefix}-ecs-agent"
}

resource "aws_cloudwatch_log_group" "rocketchat" {
  name = "${var.project_prefix}-rocketchat"
}
