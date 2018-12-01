provider "aws" {
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


resource "aws_instance" "sns" {
  ami           = "${data.aws_ami.amazon-linux-2.id}"
  instance_type   = "t2.micro"
  user_data       = "${data.template_file.sns_cloud_config.rendered}"
  security_groups = ["${aws_security_group.circles_sns_sg.id}"]
  iam_instance_profile          = "${aws_iam_instance_profile.circles_sns.id}"
  associate_public_ip_address = true
  key_name = "${aws_key_pair.circles_sns.key_name}"
  subnet_id = "${aws_subnet.public_subnet.0.id}"

  tags {
    Environment = "${var.environment}"
    Name        = "${var.project_prefix}-service"
    Project     = "${var.project}"
  }
}

data "template_file" "sns_cloud_config" {
  template = "${file("${path.module}/sns_cloud-config.yml")}"
  # vars {
  #   smtp_host       = "${var.smtp_host}"
  #   smtp_username   = "${var.smtp_username}"
  #   smtp_password   = "${var.smtp_password}"
  # }
}

resource "aws_key_pair" "circles_sns" {
  key_name   = "sns-key"
  public_key = "${file("ssh/insecure-deployer.pub")}"
}

resource "aws_security_group" "circles_sns_sg" {
  name    = "${var.project_prefix}-sg"
  vpc_id  = "${var.vpc_id}"
  
  ingress {
    from_port = 80
    to_port = 3000
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



resource "aws_cloudwatch_log_group" "sns" {
  name              = "${var.project_prefix}-logs"
  retention_in_days = "60"

  tags {
    Name        = "${var.project_prefix}-logs"
    Environment = "${var.environment}"
  }
}

## IAM

resource "aws_iam_instance_profile" "circles_sns" {
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
    app_log_group_arn = "${aws_cloudwatch_log_group.sns.arn}"
    region            = "${var.region}"    
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "${var.project_prefix}-instance-policy"
  role   = "${aws_iam_role.instance.name}"
  policy = "${data.template_file.instance_profile.rendered}"
}

/* Elastic IP for NAT */
resource "aws_eip" "network_eip" {
  vpc        = true
}

/* NAT */
resource "aws_nat_gateway" "network_nat_gateway" {
  allocation_id = "${aws_eip.network_eip.id}"
  subnet_id     = "${element(aws_subnet.public_subnet.*.id, 0)}"

  tags {
    Name        = "${var.project_prefix}-${element(var.availability_zones, count.index)}-nat"
    Environment = "${var.environment}"
  }
}

/* Public subnet */
resource "aws_subnet" "public_subnet" {
  vpc_id                  = "${var.vpc_id}"
  count                   = "${length(var.public_subnets_cidr)}"
  cidr_block              = "${element(var.public_subnets_cidr, count.index)}"
  availability_zone       = "${element(var.availability_zones, count.index)}"
  map_public_ip_on_launch = true

  tags {
    Name        = "${var.project_prefix}-${element(var.availability_zones, count.index)}-public-subnet"
    Environment = "${var.environment}"
  }
}

/* Private subnet */
resource "aws_subnet" "private_subnet" {
  vpc_id                  = "${var.vpc_id}"
  count                   = "${length(var.private_subnets_cidr)}"
  cidr_block              = "${element(var.private_subnets_cidr, count.index)}"
  availability_zone       = "${element(var.availability_zones, count.index)}"
  map_public_ip_on_launch = false

  tags {
    Name        = "${var.project_prefix}-${element(var.availability_zones, count.index)}-private-subnet"
    Environment = "${var.environment}"
  }
}

/* Routing table for private subnet */
resource "aws_route_table" "private" {
  vpc_id = "${var.vpc_id}"

  tags {
    Name        = "${var.project_prefix}-private-route-table"
    Environment = "${var.environment}"
  }
}

/* Routing table for public subnet */
resource "aws_route_table" "public" {
  vpc_id = "${var.vpc_id}"

  tags {
    Name        = "${var.project_prefix}-public-route-table"
    Environment = "${var.environment}"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${var.igw_id}"
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${aws_route_table.private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.network_nat_gateway.id}"
}

/* Route table associations */
resource "aws_route_table_association" "public" {
  count          = "${length(var.public_subnets_cidr)}"
  subnet_id      = "${element(aws_subnet.public_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "private" {
  count           = "${length(var.private_subnets_cidr)}"
  subnet_id       = "${element(aws_subnet.private_subnet.*.id, count.index)}"
  route_table_id  = "${aws_route_table.private.id}"
}

/*====
VPC's Default Security Group
======*/
resource "aws_security_group" "default" {
  name        = "${var.project_prefix}-default-sg"
  description = "Default security group to allow inbound/outbound from the VPC"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = "true"
  }

  tags {
    Environment = "${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "network_log_group" {
  name              = "${var.project_prefix}-network-logs"
  retention_in_days = "60"

  tags {
    Name        = "${var.project_prefix}-network-logs"
    Environment = "${var.environment}"
  }
}
