variable "repository_url" {
  description = "The url of the ECR repository"
}

variable "image_name" {
  description = "The name of the docker image ECR"
}

variable "project_prefix" {
  description = "Name prefix for resources."
}

variable "region" {
  description = "The region to launch the bastion host"
}

variable "ecs_cluster_name" {
  description = "The cluster that we will deploy"
}

variable "ecs_service_name" {
  description = "The ECS service that will be deployed"
}

variable "run_task_subnet_id" {
  description = "The subnet Id where single run task will be executed"
}

variable "run_task_security_group_ids" {
  type        = "list"
  description = "The security group Ids attached where the single run task will be executed"
}

variable "github_oauth_token" {
  description = "The OAuth token for the github repo to pull code from"
}

