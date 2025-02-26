# variable "container_image" {
#   description = "The container image to deploy (including tag)"
#   type        = string
# }

variable "phase_app" {
  description = "The Phase app name"
  type        = string
  default     = "example-app"
}

variable "phase_environment" {
  description = "The Phase environment name"
  type        = string
  default     = "prod"
}

variable "phase_service_token" {
  description = "The Phase service token to use for fetching secrets"
  type        = string
  sensitive   = true
}
