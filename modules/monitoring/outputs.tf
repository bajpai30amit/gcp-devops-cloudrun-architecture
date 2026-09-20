output "notification_channel_name" {
  description = "Monitoring email notification channel"
  value       = google_monitoring_notification_channel.email.name
}

output "cloud_run_5xx_alert_policy" {
  description = "Cloud Run 5xx alert policy name"
  value       = google_monitoring_alert_policy.cloud_run_5xx.name
}

output "cloud_run_latency_alert_policy" {
  description = "Cloud Run latency alert policy name"
  value       = google_monitoring_alert_policy.cloud_run_latency.name
}