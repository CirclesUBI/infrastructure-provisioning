module "code_pipeline" {
  source                      = "./modules/code_pipeline"
  repository_url              = "${module.ecs.repository_url}"
  region                      = "${var.aws_region}"
  project_prefix              = "${var.project_prefix}"
  ecs_service_name            = "${module.ecs.service_name}"
  ecs_cluster_name            = "${module.ecs.cluster_name}"
  run_task_subnet_id          = "${module.networking.private_subnets_id[0]}"
  run_task_security_group_ids = ["${module.networking.security_groups_ids}", "${module.ecs.security_group_id}"] #"${module.rds.db_access_sg_id}", 
  github_oauth_token          = "${var.circles_api_github_oauth_token}"
  image_name                  = "${var.project_prefix}"
}