resource "google_cloud_run_v2_service" "app" {
  name     = var.service_name
  project  = var.project_id
  location = var.region

  deletion_protection = false

  template {
    service_account = var.service_account

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # ---------------------------------------------------------
    # Application container
    # ---------------------------------------------------------
    containers {
      name  = "app"
      image = var.image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    # ---------------------------------------------------------
    # Google Managed Service for Prometheus sidecar
    #
    # Default configuration:
    #   Port     : 8080
    #   Path     : /metrics
    #   Interval : 30 seconds
    # ---------------------------------------------------------
    containers {
      name  = "collector"
      image = "us-docker.pkg.dev/cloud-ops-agents-artifacts/cloud-run-gmp-sidecar/cloud-run-gmp-sidecar:1.2.0"

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  # ---------------------------------------------------------
  # GitHub Actions owns the application image.
  # Terraform owns the Cloud Run infrastructure.
  # ---------------------------------------------------------
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image
    ]
  }
}


# ---------------------------------------------------------
# Public access - POC only
# ---------------------------------------------------------
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name

  role   = "roles/run.invoker"
  member = "allUsers"
}