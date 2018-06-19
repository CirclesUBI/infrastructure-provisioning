// -----------------------------------------------------------------------------
// EC2 Instance
//
// defines a t2.micro ec2 instance running on amazon linux with an attached
// security group
// -----------------------------------------------------------------------------

data "template_file" "base_cloud_config" {
  template = "${file("${path.module}/cloud-config.yaml")}"

  //compose  = "${file("${path.module}/docker-compose.yml")}"

  vars {
    cloudwatch_json = "${data.template_file.cloudwatch_config.rendered}"
    aws_access_key  = "${var.aws_access_key}"
    aws_secret_key  = "${var.aws_secret_key}"
    mongo_port      = "${var.mongo_port}"
    aws_region      = "${var.aws_region}"
  }
}

// compress cloud-init file
data "template_cloudinit_config" "this" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.base_cloud_config.rendered}"
    merge_type   = "list(append)+dict(recurse_array)+str()"
  }

  part {
    content_type = "text/cloud-config"
    content      = "${var.cloud_config}"
    merge_type   = "list(append)+dict(recurse_array)+str()"
  }
}

data "template_file" "cloudwatch_config" {
  template = "${file("${path.module}/cloudwatch.json")}"

  vars {
    log_group_name = "${var.name}-logs"
  }
}

resource "aws_instance" "this" {
  instance_type = "t2.micro"
  ami           = "ami-c7e0c82c" # Ubuntu 16.03 LTS hvm:ebs-ssd

  iam_instance_profile        = "${var.instance_profile_name}"
  subnet_id                   = "${var.subnet_id}"
  security_groups             = ["${var.security_groups}"]
  key_name                    = "${var.key_name}"
  source_dest_check           = false
  associate_public_ip_address = true

  user_data = "${data.template_cloudinit_config.this.rendered}"

  tags {
    Name = "${var.name}"
  }
}
