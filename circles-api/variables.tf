variable "project_prefix" {
  description = "Name prefix for resources."
  default     = "circles-backend"
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "app_version" {
  description = "App Version."
  default     = "1.0.0"
}
