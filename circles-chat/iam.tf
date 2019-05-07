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

resource "aws_iam_role" "chat" {
  name               = "chat"
  assume_role_policy = "${var.default_role}"
}

// -----------------------------------------------------------------------------
// Policies
// -----------------------------------------------------------------------------

resource "aws_iam_policy_attachment" "chat" {
  name       = "chat"
  roles      = ["${aws_iam_role.chat.name}"]
  policy_arn = "${aws_iam_policy.chat.arn}"
}

resource "aws_iam_policy" "chat" {
  name = "chat"

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

resource "aws_iam_policy_attachment" "chat_logging" {
  name       = "chat-logging"
  roles      = ["${aws_iam_role.chat.name}"]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
