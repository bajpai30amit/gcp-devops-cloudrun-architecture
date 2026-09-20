# ---------------------------------------------------------
# Email notification channel
# ---------------------------------------------------------

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "DevOps POC Email Alerts"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}


# ---------------------------------------------------------
# Cloud Run 5xx Error Alert
# ---------------------------------------------------------

resource "google_monitoring_alert_policy" "cloud_run_5xx" {
  project      = var.project_id
  display_name = "Cloud Run - 5xx Errors"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Run 5xx responses"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${var.cloud_run_service_name}"
        AND metric.type = "run.googleapis.com/request_count"
        AND metric.labels.response_code_class = "5xx"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "60s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.name
  ]

  documentation {
    content = <<-EOT
      Cloud Run service ${var.cloud_run_service_name} is returning HTTP 5xx responses.

      Check Cloud Run application logs and the latest deployed revision.
    EOT

    mime_type = "text/markdown"
  }
}


# ---------------------------------------------------------
# Cloud Run High Latency Alert
#
# request_latencies is measured in milliseconds.
# Trigger if p95 latency exceeds 2 seconds for 5 minutes.
# ---------------------------------------------------------

resource "google_monitoring_alert_policy" "cloud_run_latency" {
  project      = var.project_id
  display_name = "Cloud Run - High Request Latency"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Run p95 latency > 2 seconds"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${var.cloud_run_service_name}"
        AND metric.type = "run.googleapis.com/request_latencies"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = 2000
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MAX"

        group_by_fields = [
          "resource.labels.service_name"
        ]
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.name
  ]

  documentation {
    content = <<-EOT
      Cloud Run service ${var.cloud_run_service_name} has high request latency.

      The p95 request latency exceeded 2 seconds for 5 minutes.
    EOT

    mime_type = "text/markdown"
  }
}