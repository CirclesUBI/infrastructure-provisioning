module "code_pipeline" {
  source                      = "./modules/code_pipeline"
  vpc_id                      = "${data.terraform_remote_state.circles_backend.vpc_id}"
  repository_url              = "${module.ecs.repository_url}"
  region                      = "${var.aws_region}"
  project_prefix              = "${var.project_prefix}"
  ecs_service_name            = "${module.ecs.service_name}"
  ecs_cluster_name            = "${module.ecs.cluster_name}"
  run_task_subnet_id          = "${module.networking.private_subnets_id[0]}"
  db_subnet_id                = "${module.rds.subnet_id}"
  run_task_security_group_ids = ["${module.networking.security_groups_ids}", "${module.ecs.security_group_id}"] #"${module.rds.db_access_sg_id}", 
  github_oauth_token          = "${var.circles_api_github_oauth_token}"
  github_branch               = "master"
  image_name                  = "${var.project_prefix}-ecr",
  database_name               = "${var.database_name}"
  database_user               = "${var.database_user}"
  database_host               = "${var.database_host}"
  database_password           = "${var.database_password}"
  database_port               = "${var.database_port}"
  private_key                 = "${var.private_key}"
  cognito_pool_id             = "${data.terraform_remote_state.cognito.cognito_userpool_id}"
}