output "alb-dns" {
  value = "${module.alb.dns_name}"
}

output "image" {
  value = "${aws_launch_configuration.circles_blog.image_id}"
}
