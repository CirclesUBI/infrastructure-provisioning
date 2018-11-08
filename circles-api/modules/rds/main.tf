resource "aws_subnet" "rds" {
  count = "${length(var.availability_zones)}"
  vpc_id = "${var.vpc_id}"
  cidr_block = "${var.cidr_block}"
  map_public_ip_on_launch = true
  availability_zone = "${element(var.availability_zones, count.index)}"
  tags {
    Name = "rds-${element(var.availability_zones, count.index)}"
    Environment = "${var.environment}"
  }
}

resource "aws_db_subnet_group" "default" {
  name = "${var.rds_instance_identifier}-subnet-group"
  description = "RDS subnet group"
  subnet_ids = ["${aws_subnet.rds.*.id}"]
}

resource "aws_security_group" "rds" {
  name = "rds_security_group"
  description = "RDS PostgreSQL"
  vpc_id = "${var.vpc_id}"
  # Keep the instance private by only allowing traffic from the web server.
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = ["${var.ecs_security_group}"]
  }
  # Allow all outbound traffic.
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "rds-security-group"
    Environment = "${var.environment}"
  }
}

resource "aws_db_instance" "default" {
  identifier = "${var.rds_instance_identifier}"
  allocated_storage = "${var.allocated_storage}"
  engine = "postgres"
  engine_version = "10.5"
  instance_class = "${var.instance_class}"
  name = "${var.database_name}"
  username = "${var.database_user}"
  password = "${var.database_password}"
  db_subnet_group_name = "${aws_db_subnet_group.default.id}"
  vpc_security_group_ids = ["${aws_security_group.rds.id}"]
  skip_final_snapshot = true
  final_snapshot_identifier = "Ignore"
}

resource "aws_db_parameter_group" "default" {
  name = "${var.rds_instance_identifier}-param-group"
  description = "Parameter group for postgres10.5"
  family = "postgres10.5"
  parameter {
    name = "character_set_server"
    value = "utf8"
  }
  parameter {
    name = "character_set_client"
    value = "utf8"
  }
}