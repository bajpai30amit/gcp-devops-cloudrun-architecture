resource "google_pubsub_topic" "events" {
  project = var.project_id
  name    = var.topic_name
}
resource "google_pubsub_subscription" "cloud_run_push" {
  project = var.project_id
  name    = "${var.topic_name}-cloud-run-sub"
  topic   = google_pubsub_topic.events.id

  ack_deadline_seconds = 30

  push_config {
    push_endpoint = var.cloud_run_push_endpoint

    oidc_token {
      service_account_email = var.push_service_account_email
    }
  }
}