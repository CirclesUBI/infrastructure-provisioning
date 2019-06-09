variable "website_domain" {
  description = "Domain to be certified."
}

variable "common_tags" {
  type        = "map"
  description = "Common tags for all resources."
}

variable "hosted_zone_id" {
  description = "Zone of hosted domain."
}
