output "repository_url" {
  value = "${aws_ecr_repository.circles_api.repository_url}"
}

output "cluster_name" {
  value = "${aws_ecs_cluster.circles_api.name}"
}

output "service_name" {
  value = "${aws_ecs_service.circles_api.name}"
}

output "alb_dns_name" {
  value = "${aws_alb.circles_api.dns_name}"
}

output "alb_zone_id" {
  value = "${aws_alb.circles_api.zone_id}"
}

output "security_group_id" {
  value = "${aws_security_group.ecs_service.id}"
}