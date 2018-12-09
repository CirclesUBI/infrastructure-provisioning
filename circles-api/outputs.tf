output "ecs_service_name" {
  value = "${module.ecs.service_name}"
}

output "ecs_cluster_name" {
  value = "${module.ecs.cluster_name}"
}

output "dns_name" {
  value = "${module.ecs.alb_dns_name}"
}

output "db_name" {
  value = "${module.rds.db_name}"
}

output "db_port" {
  value = "${module.rds.db_port}"
}

output "db_username" {
  value = "${module.rds.db_username}"
}

output "db_host" {
  value = "${module.rds.db_host}"
}

output "db_security_group" {
  value = "${module.rds.db_security_group}"
}

