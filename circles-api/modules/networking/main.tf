

data "aws_availability_zones" "available" {}

/* Elastic IP for NAT */
resource "aws_eip" "circles_api" {
  vpc        = true
}

/* NAT */
resource "aws_nat_gateway" "circles_api" {
  allocation_id = "${aws_eip.circles_api.id}"
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
  nat_gateway_id         = "${aws_nat_gateway.circles_api.id}"
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
  name        = "${var.environment}-default-sg"
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

resource "aws_cloudwatch_log_group" "circles_api" {
  name              = "${var.project_prefix}-circles-api"
  retention_in_days = "60"

  tags {
    Name        = "${var.project_prefix}-circles-api"
    Environment = "${var.environment}"
  }
}
