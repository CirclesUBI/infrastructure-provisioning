variable "vpc_id" {
  description = "The VPC to run the codepipeline in"
}

variable "repository_url" {
  description = "The url of the ECR repository"
}

variable "image_name" {
  description = "The name of the docker image ECR"
}

variable "project" {
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

variable "db_subnet_id" {
  description = "The subnet where the DB is located"
}

variable "run_task_security_group_ids" {
  type        = "list"
  description = "The security group Ids attached where the single run task will be executed"
}

variable "github_oauth_token" {
  description = "The OAuth token for the github repo to pull code from"
}

variable "github_branch" {
  description = "The github branch to pull code from"
}


variable "database_name" {
  description = "Database name for the api"
}

variable "database_password" {
  description = "Database password for the api"
}

variable "database_user" {
  description = "Database user for the api"
}

variable "database_host" {
  description = "Database host for the api"
}

variable "database_port" {
  description = "Database port for the api"
}

variable "private_key" {
  description = "The user's private key"
}

variable "cognito_pool_id" {
  description = "Cognito pool id"
}

variable "cognito_client_id" {
  description = "Cognito client id"
}

variable "cognito_pool_jwt_kid" {
  description = "Cognito pool jwt KID"
}

variable "cognito_pool_jwt_n" {
  description = "Cognito pool jwt N"
}

variable "android_platform_gcm_arn" {
  description = "Adroid platform GCN ARN"
}

variable "cognito_test_username" {
  description = "Admin cognito username for API Tests"
}

variable "cognito_test_password" {
  description = "Admin cognito user password for API Tests"
}

variable "blockchain_network_id" {
  description = "Port number of blockchain network interface"
}