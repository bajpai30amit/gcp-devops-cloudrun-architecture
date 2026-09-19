output "topic_name" {
  value = google_pubsub_topic.events.name
}

output "topic_id" {
  value = google_pubsub_topic.events.id
}