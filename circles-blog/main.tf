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
  key_name        = "${aws_key_pair.circles_blog.key_name}"
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
  load_balancers = ["${module.elb.this_elb_id}"]

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

######
# ELB
######
module "elb" {
  source = "terraform-aws-modules/elb/aws"

  name = "${var.project_prefix}-elb"

  subnets         = ["${module.networking.public_subnets_id}"]
  security_groups = ["${aws_security_group.circles_blog_alb_sg.id}"]
  internal        = false

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "HTTP"
      lb_port           = "80"
      lb_protocol       = "HTTP"
    },
  ]

  health_check = [
    {
      target              = "HTTP:80/"
      interval            = 30
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout             = 5
    },
  ]

  tags = {
    Name        = "${var.project_prefix}-logs"
    Environment = "${var.environment}"
  }
}


data "template_file" "blog_cloud_config" {
  template = "${file("blog_cloud-config.yml")}"
  vars {
    smtp_host       = "${var.smtp_host}"
    smtp_username   = "${var.smtp_username}"
    smtp_password   = "${var.smtp_password}"
  }
}


resource "aws_key_pair" "circles_blog" {
  key_name   = "blog-key"
  public_key = "${file("ssh/insecure-deployer.pub")}"
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

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
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

resource "aws_security_group_rule" "ssh" {
  security_group_id = "${aws_security_group.circles_blog_sg.id}"
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/32"]
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
