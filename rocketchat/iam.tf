// -----------------------------------------------------------------------------
// Instance Profiles / Roles
// -----------------------------------------------------------------------------

variable "default_role" {
  type = "string"

  default = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

// ethstats

# resource "aws_iam_instance_profile" "rocketchat" {
#   name = "rocketchat"
#   role = "${aws_iam_role.rocketchat.name}"
# }

resource "aws_iam_role" "rocketchat" {
  name               = "rocketchat"
  assume_role_policy = "${var.default_role}"
}

// -----------------------------------------------------------------------------
// Policies
// -----------------------------------------------------------------------------

// Read ws_secret For Ethstats

resource "aws_iam_policy_attachment" "rocketchat" {
  name       = "rocketchat"
  roles      = ["${aws_iam_role.rocketchat.name}"]
  policy_arn = "${aws_iam_policy.rocketchat.arn}"
}

resource "aws_iam_policy" "rocketchat" {
  name = "rocketchat"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "arn:aws:secretsmanager:eu-central-1:183869895864:secret:circles-ws-secret-nhzYC3"
        }
    ]
}
EOF
}

// Write Cloudwatch Logs

resource "aws_iam_policy_attachment" "rocketchat_logging" {
  name       = "rocketchat-logging"
  roles      = ["${aws_iam_role.rocketchat.name}"]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
