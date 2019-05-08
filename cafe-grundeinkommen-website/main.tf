terraform {
  backend "s3" {
    bucket         = "cafe-grundeinkommen-website-terraform-state"
    region         = "eu-central-1"
    key            = "cafe-grundeinkommen-website-terraform.tfstate"
    dynamodb_table = "cafe-grundeinkommen-website-terraform"
    encrypt        = true
  }
}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.aws_region}"
}

data "terraform_remote_state" "circles_vpc" {
  backend = "s3"
  config {
    bucket         = "circles-vpc-terraform-state"
    region         = "eu-central-1"
    key            = "circles-vpc-terraform.tfstate"
    dynamodb_table = "circles-vpc-terraform"
    encrypt        = true
  }
}

resource "aws_route53_zone" "joincircles" {
  name = "cafe-grundeinkommen.org"
}

# resource "aws_acm_certificate" "cert" {
#   domain_name       = "cafe-grundeinkommen.org"
#   validation_method = "DNS"
# }

# resource "aws_route53_record" "cert_validation_dns_record" {
#   # name = "_116690e4e4055e78cf9f18164a99bb4f.api.joincircles.net"
#   # type    = "CNAME"
#   # ttl = "60"
#   # zone_id           = "Z1H1OJRKIZ7DT2"
#   # allow_overwrite = true

#   name = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
#   type = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
#   zone_id = "${aws_route53_zone.joincircles.id}"
#   records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
#   ttl = 60
# }

# resource "aws_acm_certificate_validation" "cert_validation" {
#   certificate_arn = "${aws_acm_certificate.cert.arn}"
#   validation_record_fqdns = ["${aws_route53_record.cert_validation_dns_record.fqdn}"]
# }



# id                = Z1H1OJRKIZ7DT2__116690e4e4055e78cf9f18164a99bb4f.api.joincircles.net._CNAME
# allow_overwrite   = true
# fqdn              = _116690e4e4055e78cf9f18164a99bb4f.api.joincircles.net
# health_check_id   =

# records.#         = 1
# records.459540408 = _370b295ac76732fa2a332bd977b56208.tljzshvwok.acm-validations.aws.




#                     = arn:aws:acm:eu-central-1:183869895864:certificate/50a39992-4866-4f90-84ee-2e39cf4d7513
# validation_record_fqdns.#          = 1
# validation_record_fqdns.1360131667 = _116690e4e4055e78cf9f18164a99bb4f.api.joincircles.net.

/*====
Variables used across all modules
======*/
locals {
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]
}

variable "cafe_public_cidrs" {
  default = ["10.0.4.0/26", "10.0.4.64/26"]
}

variable "cafe_private_cidrs" {
  default = ["10.0.4.128/26", "10.0.4.192/26"]
}

module "networking" {
  source               = "./modules/networking"
  project_prefix       = "${var.project_prefix}"
  environment          = "${var.environment}"
  vpc_id               = "${data.terraform_remote_state.circles_vpc.vpc_id}"
  igw_id               = "${data.terraform_remote_state.circles_vpc.igw_id}"
  public_subnet_cidr   = "${element(var.cafe_public_cidrs,0)}"
  region               = "${var.aws_region}"
  availability_zone    = "${element(local.availability_zones,0)}"
}


## ECS

resource "aws_ecs_cluster" "cafe" {
  name = "${var.project_prefix}-cluster"
}

data "template_file" "cafe_task_definition" {
  template   = "${file("${path.module}/cafe-task-def.json")}"
  depends_on = ["aws_alb.cafe"]

  vars {
    log_group_region        = "${var.aws_region}"
    log_group_name          = "${aws_cloudwatch_log_group.cafe.name}"
    mariadb_host            = "${var.mariadb_host}"
    mariadb_port_number     = "${var.mariadb_port_number}"
    mariadb_database_user   = "${var.mariadb_database_user}"
    mariadb_database_name   = "${var.mariadb_database_name}"
    allow_empty_password    = "${var.allow_empty_password}"
    mariadb_user            = "${var.mariadb_user}"
    mariadb_database        = "${var.mariadb_database}"
    task_family             = "${aws_ecs_task_definition.cafe.family}"
  }
}

resource "aws_ecs_task_definition" "cafe" {
  family                = "cafe-taskdef"
  container_definitions = "${data.template_file.cafe_task_definition.rendered}"
}

resource "aws_ecs_service" "cafe" {
  name                               = "${var.project_prefix}-ecs-service"
  cluster                            = "${aws_ecs_cluster.cafe.id}"
  task_definition                    = "${aws_ecs_task_definition.cafe.arn}"
  desired_count                      = "${var.asg_desired}"
  iam_role                           = "${aws_iam_role.ecs_service.name}"
  deployment_maximum_percent         = "100"
  deployment_minimum_healthy_percent = "50"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.cafe.id}"
    container_name   = "cafe"
    container_port   = "3000"
  }

  depends_on = [
    "aws_iam_role_policy.ecs_service",
    "aws_alb_listener.cafe_http",
    "aws_alb_listener.cafe_https",
  ]
}

# data "template_file" "cloud_config" {
#   template = "${file("${path.module}/cloud-config.yml")}"

#   vars {
#     aws_region                  = "${var.aws_region}"
#     wordpress_log_group_name = "${aws_cloudwatch_log_group.cafe.name}"
#   }
# }

resource "aws_security_group" "instance_sg" {
  description = "controls direct access to application instances"
  vpc_id      = "${data.terraform_remote_state.circles_vpc.vpc_id}"
  name        = "${var.project_prefix}-instsg"

  ingress {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80

    # security_groups = [
    #   "${aws_security_group.lb_sg.id}",
    # ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    # security_groups = [
    #   "${aws_security_group.lb_sg.id}",
    # ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443

    # security_groups = [
    #   "${aws_security_group.lb_sg.id}",
    # ]
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
    Project     = "${var.project}"
  }
}

resource "aws_key_pair" "cafe" {
  key_name   = "cafe-grundeinkommen-website"
  public_key = "${file("ssh/cafe-grundeinkommen-website.pub")}"
}

resource "aws_instance" "wordpress" {
  ami = "ami-0d33e81ffd9511552" // eu-central-1	bionic	18.04 LTS	amd64	hvm:ebs-ssd	20190429	ami-0d33e81ffd9511552	hvm

  # free tier eligible
  instance_type = "t2.micro"

  availability_zone = "${element(local.availability_zones,0)}"
  security_groups = ["${aws_security_group.instance_sg.id}"]
  subnet_id = "${module.networking.public_subnet_id}"

  key_name = "${aws_key_pair.cafe.key_name}"

  # add a public IP address
  associate_public_ip_address = true

  user_data                   = "${data.template_file.cloud_config.rendered}"

  root_block_device = {
    "volume_type"           = "standard"
    "volume_size"           = 15
    "delete_on_termination" = false
  }

  tags {
    Project     = "${var.project}"
    Name        = "${var.project_prefix}-instance"
    Environment = "${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "cafe" {
  name              = "${var.project_prefix}-logs"
  retention_in_days = "60"

  tags {
    Project     = "${var.project}"
    Name        = "${var.project_prefix}-logs"
    Environment = "${var.environment}"
  }
}