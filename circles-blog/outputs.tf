output "alb-dns" {
  value = "${module.elb.this_elb_dns_name}"
}

output "image" {
  value = "${aws_launch_configuration.circles_blog.image_id}"
}