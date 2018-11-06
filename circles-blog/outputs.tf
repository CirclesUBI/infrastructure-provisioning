output "alb-dns" {
  value = "${module.alb.dns_name}"
}

output "image" {
  value = "${aws_launch_configuration.circles_blog.image_id}"
}

# output "http_tcp_listeners" {
#   value = "${local.http_tcp_listeners}"
# }

# output "https_listeners" {
#   value = "${local.https_listeners}"
# }

# output "lb_id" {
#   value = "${module.alb.load_balancer_id}"
# }
