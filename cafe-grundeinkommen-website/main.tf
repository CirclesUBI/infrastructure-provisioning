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
  access_key          = "${var.access_key}"
  secret_key          = "${var.secret_key}"
  region              = "${var.aws_region}"
  allowed_account_ids = ["${var.aws_account_id}"]
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

# resource "aws_route53_zone" "joincircles" {
#   name = "cafe-grundeinkommen.org"
# }

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
  project_prefix       = "${var.project}"
  environment          = "${var.environment}"
  vpc_id               = "${data.terraform_remote_state.circles_vpc.vpc_id}"
  igw_id               = "${data.terraform_remote_state.circles_vpc.igw_id}"
  public_subnets_cidr  = "${var.cafe_public_cidrs}"
  private_subnets_cidr = "${var.cafe_private_cidrs}"
  region               = "${var.aws_region}"
  availability_zones   = "${local.availability_zones}"
}

data "template_file" "cloud_config" {
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    aws_region                  = "${var.aws_region}"
    wordpress_log_group_name    = "${aws_cloudwatch_log_group.cafe.name}"
  }
}

resource "aws_launch_configuration" "cafe" {
  image_id          = "ami-0d33e81ffd9511552"
  instance_type     = "t2.micro"
  security_groups   = ["${aws_security_group.instance_sg.id}"]
  key_name          = "${aws_key_pair.cafe.key_name}"
  user_data         = "${data.template_file.cloud_config.rendered}"
  // iam_instance_profile        = "${aws_iam_instance_profile.chat.name}"
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "cafe" {
  launch_configuration  = "${aws_launch_configuration.cafe.id}"
  vpc_zone_identifier   = ["${module.networking.private_subnets_id}"]
  load_balancers        = ["${aws_alb.cafe.name}"]
  min_size              = 1
  max_size              = 3
  desired_capacity      = 1
  target_group_arns     = ["${aws_alb_target_group.cafe.arn}"]

  tag {
    key                 = "Name"
    value               = "${var.project}-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "${var.project}"
    propagate_at_launch = true
  }
}

resource "aws_alb" "cafe" {
  name                = "${var.project}-alb"
  security_groups     = ["${aws_security_group.lb_sg.id}"]
  subnets             = ["${module.networking.public_subnets_id}"]
  enable_deletion_protection = false

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.project}-alb"
    )
  )}"
}


resource "aws_alb_target_group" "cafe" {
  name     = "cafe-alb-tg" // "name" cannot be longer than 32 characters
  port     = "80"
  protocol = "HTTP"
  vpc_id   = "${data.terraform_remote_state.circles_vpc.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

  stickiness {
    type = "lb_cookie"
  }

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.project}-alb-tg"
    )
  )}"
}

resource "aws_autoscaling_attachment" "cafe" {
  alb_target_group_arn   = "${aws_alb_target_group.cafe.arn}"
  autoscaling_group_name = "${aws_autoscaling_group.cafe.id}"
}

# resource "aws_alb_listener" "cafe" {
#   load_balancer_arn = "${aws_alb.cafe.id}"
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   // certificate_arn   = "${data.aws_acm_certificate.cafe.arn}"

#   default_action {
#     target_group_arn = "${aws_alb_target_group.cafe.id}"
#     type             = "forward"
#   }
# }

resource "aws_alb_listener" "cafe_http" {
  load_balancer_arn = "${aws_alb.cafe.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.cafe.id}"
    type             = "forward"
  }
}

# resource "aws_alb_listener" "cafe_https" {
#   load_balancer_arn = "${aws_alb.cafe.id}"
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   // certificate_arn   = "${aws_acm_certificate.cafe.arn}"

#   default_action {
#     target_group_arn = "${aws_alb_target_group.cafe.id}"
#     type             = "forward"
#   }
# }

### Security

resource "aws_security_group" "lb_sg" {
  description = "controls access to the application ELB"

  vpc_id = "${data.terraform_remote_state.circles_vpc.vpc_id}"
  name   = "${var.project}-lb-sg"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ingress {
  #   protocol    = "tcp"
  #   from_port   = 443
  #   to_port     = 443
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.project}-lb-sg"
    )
  )}"
}
resource "aws_security_group" "instance_sg" {
  description = "controls direct access to application instances"
  vpc_id      = "${data.terraform_remote_state.circles_vpc.vpc_id}"
  name        = "${var.project}-instsg"

  ingress {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80

    security_groups = [
      "${aws_security_group.lb_sg.id}"
    ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    security_groups = [
      "${aws_security_group.lb_sg.id}"
    ]
  }

  # ingress {
  #   protocol  = "tcp"
  #   from_port = 443
  #   to_port   = 443

  #   security_groups = [
  #     "${aws_security_group.lb_sg.id}"
  #   ]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.project}-instance-sg"
    )
  )}"
}

resource "aws_key_pair" "cafe" {
  key_name   = "cafe-grundeinkommen-website"
  public_key = "${file("ssh/cafe-grundeinkommen-website.pub")}"
}

resource "aws_cloudwatch_log_group" "cafe" {
  name              = "${var.project}-logs"
  retention_in_days = "30"

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.project}-logs"
    )
  )}"
}