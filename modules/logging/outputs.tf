output "sink_name" {
  value = google_logging_project_sink.application_logs.name
}

output "sink_id" {
  value = google_logging_project_sink.application_logs.id
}