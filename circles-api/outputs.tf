output "ecs_service_name" {
  value = "${module.ecs.service_name}"
}

output "ecs_cluster_name" {
  value = "${module.ecs.cluster_name}"
}

output "dns_name" {
  value = "${module.ecs.alb_dns_name}"
}