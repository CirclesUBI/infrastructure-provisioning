terraform {
  backend "s3" {
    bucket         = "circles-blog-terraform"
    region         = "eu-central-1"
    key            = "circles-blog-terraform.tfstate"
    dynamodb_table = "circles-blog-terraform"
    encrypt        = true
  }
}

# AWS
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.aws_region}"
}

data "aws_ami" "amazon-linux-2" {
 most_recent = true

 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }

 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }
}

locals {
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]  
}

variable "blog_public_cidrs" {
  default = ["10.0.1.0/26", "10.0.1.64/26"]
}

variable "blog_private_cidrs" {
  default = ["10.0.1.128/26", "10.0.1.192/26"]
}

module "networking" {
  source               = "./modules/networking"
  project_prefix       = "${var.project_prefix}"
  environment          = "${var.environment}"
  vpc_id               = "${var.circles_backend_vpc_id}"
  igw_id               = "${var.circles_backend_igw_id}" 
  public_subnets_cidr  = "${var.blog_public_cidrs}"
  private_subnets_cidr = "${var.blog_private_cidrs}"
  region               = "${var.aws_region}"
  availability_zones   = "${local.availability_zones}"
}

resource "aws_launch_configuration" "circles_blog" {
  name_prefix     = "${var.project_prefix}-"
  image_id        = "${data.aws_ami.amazon-linux-2.id}" #"ami-7c4f7097"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.circles_blog_sg.id}"]
  user_data       = "${data.template_file.blog_cloud_config.rendered}"
  iam_instance_profile          = "${aws_iam_instance_profile.circles_blog.id}"
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  } 
}

######
# Launch configuration and autoscaling group
######
module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  name = "${var.project_prefix}-asg-service"
  target_group_arns = ["${module.alb.target_group_arns}"]

  # Launch configuration
  launch_configuration          = "${aws_launch_configuration.circles_blog.name}"
  create_lc                     = false
  recreate_asg_when_lc_changes  = true

  # Auto scaling group
  asg_name                  = "${var.project_prefix}-asg"
  vpc_zone_identifier       = ["${module.networking.public_subnets_id}"]
  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 2
  wait_for_capacity_timeout = 0

  tags = [
    {
      key = "Name"
      value = "${var.project_prefix}-asg"
      propagate_at_launch = true
    },
    {
      key = "Environment"
      value = "${var.environment}"
      propagate_at_launch = true
    }
  ]
}

resource "aws_cloudwatch_metric_alarm" "scaling_app_high" {

  alarm_name = "${var.project_prefix}-cpu-over-load"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "1"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "75"

  dimensions {
    AutoScalingGroupName = "${module.asg.this_autoscaling_group_name}"
  }

  alarm_actions = ["${aws_autoscaling_policy.scale_out_scaling_app.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "scaling_app_low" {

  alarm_name = "${var.project_prefix}-cpu-under-load"
  comparison_operator = "LessThanThreshold" 
  evaluation_periods = "1"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "300"
  statistic = "Average"
  threshold = "60"

  dimensions {
    AutoScalingGroupName = "${module.asg.this_autoscaling_group_name}"
  }

  alarm_actions = ["${aws_autoscaling_policy.scale_in_scaling_app.arn}"]
}

resource "aws_autoscaling_policy" "scale_out_scaling_app" {

    name = "${var.project_prefix}-cpu-scale-out"
    scaling_adjustment = 1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${module.asg.this_autoscaling_group_name}"
}

resource "aws_autoscaling_policy" "scale_in_scaling_app" {

    name = "${var.project_prefix}-cpu-scale-in"
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${module.asg.this_autoscaling_group_name}"
}


######
# ALB
######
module "alb" {
  # source               = "./modules/alb"
  source                        = "terraform-aws-modules/alb/aws"

  vpc_id                        = "${var.circles_backend_vpc_id}"
  load_balancer_name            = "${var.project_prefix}-alb"

  subnets         = ["${module.networking.public_subnets_id}"]
  security_groups = ["${aws_security_group.circles_blog_alb_sg.id}"]
  
  # enable_cross_zone_load_balancing = true
  logging_enabled = false

  http_tcp_listeners            = "${list(map("port", "80", "protocol", "HTTP"))}"
  http_tcp_listeners_count      = "1"
  https_listeners               = "${list(map("certificate_arn", "arn:aws:acm:eu-central-1:183869895864:certificate/64369cee-a0c2-4eb3-9123-be01fba83bd9", "port", 443))}"
  https_listeners_count         = "1"
  target_groups                 = "${list(map("name", "circles-blog-http", "backend_protocol", "HTTP", "backend_port", "80"))}" # , map("name", "circles-blog-https", "backend_protocol", "HTTPS", "backend_port", "443" )
  target_groups_count           = "1"

  tags                          = "${map("Environment", "${var.environment}", "Name", "${var.project_prefix}-alb")}"
}

data "template_file" "blog_cloud_config" {
  template = "${file("blog_cloud-config.yml")}"
  vars {
    smtp_host       = "${var.smtp_host}"
    smtp_username   = "${var.smtp_username}"
    smtp_password   = "${var.smtp_password}"
  }
}


resource "aws_security_group" "circles_blog_sg" {
  name    = "${var.project_prefix}-sg"
  vpc_id  = "${var.circles_backend_vpc_id}"
  
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
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

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "circles_blog_alb_sg" {
  name = "${var.project_prefix}-alb-sg"
  description = "controls access to the application ALB"
  vpc_id  = "${var.circles_backend_vpc_id}"  

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
  }
}


resource "aws_cloudwatch_log_group" "blog" {
  name              = "${var.project_prefix}-logs"
  retention_in_days = "60"

  tags {
    Name        = "${var.project_prefix}-logs"
    Environment = "${var.environment}"
  }
}

## IAM

resource "aws_iam_instance_profile" "circles_blog" {
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
    app_log_group_arn = "${aws_cloudwatch_log_group.blog.arn}"
    net_log_group_arn = "${module.networking.log_group_arn}"
    region            = "${var.aws_region}"
    s3_bucket         = "${var.blog_s3_backup_bucket}"
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "${var.project_prefix}-instance-policy"
  role   = "${aws_iam_role.instance.name}"
  policy = "${data.template_file.instance_profile.rendered}"
}
