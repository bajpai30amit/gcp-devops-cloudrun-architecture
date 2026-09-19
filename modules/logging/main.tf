resource "google_logging_project_sink" "application_logs" {
  name        = "application-logs-sink"
  project     = var.project_id
  destination = "storage.googleapis.com/${var.log_bucket_name}"

  filter = <<EOT
resource.type="cloud_run_revision"
EOT

  unique_writer_identity = true
}