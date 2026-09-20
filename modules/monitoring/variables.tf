variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cloud_run_service_name" {
  description = "Cloud Run service to monitor"
  type        = string
}

variable "region" {
  description = "Cloud Run region"
  type        = string
}

variable "notification_email" {
  description = "Email address for monitoring alerts"
  type        = string
}