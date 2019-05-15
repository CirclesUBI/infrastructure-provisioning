resource "aws_subnet" "rds" {
  count = "${length(var.availability_zones)}"
  vpc_id = "${var.vpc_id}"
  cidr_block = "${element(var.cidr_blocks, count.index)}"
  map_public_ip_on_launch = true
  availability_zone = "${element(var.availability_zones, count.index)}"

  tags = "${merge(
    var.common_tags,
    map(
      "name", "${var.project}-rds-${element(var.availability_zones, count.index)}"
    )
  )}"
}

resource "aws_route_table" "rds" {
  vpc_id = "${var.vpc_id}"

  tags = "${merge(
    var.common_tags,
    map(
      "name", "${var.project}-rds-route-table"
    )
  )}"
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.rds.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${var.igw_id}"
}

resource "aws_route_table_association" "public" {
  count          = "${length(var.cidr_blocks)}"
  subnet_id      = "${element(aws_subnet.rds.*.id, count.index)}"
  route_table_id = "${aws_route_table.rds.id}"
}

resource "aws_db_subnet_group" "default" {
  name = "${var.project}-${var.rds_instance_identifier}-subnet-group"
  description = "RDS subnet group"
  subnet_ids = ["${aws_subnet.rds.*.id}"]

  tags = "${merge(
    var.common_tags,
    map(
      "name", "${var.project}-rds-subnet-group"
    )
  )}"
}

resource "aws_security_group" "rds" {
  name = "${var.project}-rds-sg"
  description = "RDS PostgreSQL"
  vpc_id = "${var.vpc_id}"
  # Keep the instance private by only allowing traffic from the web server.
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    // security_groups = ["${var.security_group_ids}"]
  }
  # Allow all outbound traffic.
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${merge(
    var.common_tags,
    map(
      "name", "${var.project}-rds-sg"
    )
  )}"
}

resource "aws_db_instance" "default" {
  name = "${var.database_name}"
  identifier = "${var.rds_instance_identifier}"
  allocated_storage = "${var.allocated_storage}"
  engine = "postgres"
  engine_version = "10.6"
  instance_class = "${var.instance_class}"  
  username = "${var.database_user}"
  password = "${var.database_password}"
  db_subnet_group_name = "${aws_db_subnet_group.default.id}"
  vpc_security_group_ids = ["${aws_security_group.rds.id}"]
  skip_final_snapshot = true
  final_snapshot_identifier = "Ignore"
  publicly_accessible = true

  tags = "${merge(
    var.common_tags,
    map(
      "name", "${var.project}-rds"
    )
  )}"
}

resource "aws_db_parameter_group" "default" {
  name = "${var.rds_instance_identifier}-param-group"
  description = "Parameter group for postgres9.6"
  family = "postgres9.6"
  # parameter {
  #   name = "character_set_server"
  #   value = "utf8"
  # }
  # parameter {
  #   name = "character_set_client"
  #   value = "utf8"
  # }
}