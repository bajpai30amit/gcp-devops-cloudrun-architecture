resource "google_storage_bucket" "backup" {
  name     = var.bucket_name
  project  = var.project_id
  location = var.location

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }

    action {
      type = "Delete"
    }
  }

  public_access_prevention = "enforced"
}