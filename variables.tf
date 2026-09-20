variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Primary GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "devops-poc"
}
variable "notification_email" {
  description = "Email address used for Cloud Monitoring alerts"
  type        = string
}