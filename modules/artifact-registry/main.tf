resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_name

  description = "Docker container images for DevOps architecture"

  format = "DOCKER"
}