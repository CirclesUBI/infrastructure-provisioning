resource "aws_alb_target_group" "circles_api" {
  name     = "${var.project_prefix}-alb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.circles_backend.id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }
}

/* security group for ALB */
resource "aws_security_group" "web_inbound_sg" {
  name        = "${var.environment}-web-inbound-sg"
  description = "Allow HTTP from Anywhere into ALB"
  vpc_id      = "${aws_vpc.circles_backend.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.project_prefix}-web-inbound-sg"
    Environment = "${var.environment}"
  }
}

resource "aws_alb" "circles_api" {
  name            = "${var.project_prefix}-alb"
  subnets         = ["${var.public_subnet_ids}"]
  security_groups = ["${var.security_groups_ids}", "${aws_security_group.web_inbound_sg.id}"]

  tags {
    Name        = "${var.project_prefix}-alb"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_listener" "circles_api" {
  load_balancer_arn = "${aws_alb.circles_api.arn}"
  port              = "80"
  protocol          = "HTTP"
  depends_on        = ["aws_alb_target_group.circles_api"]

  default_action {
    target_group_arn = "${aws_alb_target_group.circles_api.arn}"
    type             = "forward"
  }
}