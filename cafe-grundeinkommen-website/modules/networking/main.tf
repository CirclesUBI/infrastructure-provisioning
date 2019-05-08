/* Elastic IP for NAT */
resource "aws_eip" "network_eip" {
  vpc        = true
}

/* Public subnet */
resource "aws_subnet" "public_subnet" {
  vpc_id                  = "${var.vpc_id}"
  cidr_block              = "${var.public_subnet_cidr}"
  availability_zone       = "${var.availability_zone}"
  map_public_ip_on_launch = true

  tags {
    Name        = "${var.project_prefix}-${var.availability_zone}-public-subnet"
    Environment = "${var.environment}"
  }
}


/* NAT */
resource "aws_nat_gateway" "network_nat_gateway" {
  allocation_id = "${aws_eip.network_eip.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"

  tags {
    Name        = "${var.project_prefix}-${var.availability_zone}-nat"
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

/* Route table associations */
resource "aws_route_table_association" "public" {
  count          = "${length(var.public_subnet_cidr)}"
  subnet_id      = "${element(aws_subnet.public_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

// todo: this is only relevant if it's behind a load balancer

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
