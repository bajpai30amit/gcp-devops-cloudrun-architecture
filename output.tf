output "project_id" {
  value = var.project_id
}

output "vpc_name" {
  value = module.networking.network_name
}

output "subnet_name" {
  value = module.networking.subnet_name
}

output "artifact_registry" {
  value = module.artifact_registry.repository_url
}

output "backup_bucket" {
  value = module.storage.bucket_name
}

output "pubsub_topic" {
  value = module.pubsub.topic_name
}

output "application_service_accounts" {
  value = module.iam.service_accounts
}


output "cloud_run_url" {
  description = "Cloud Run application URL"
  value       = module.cloud_run.service_uri
}