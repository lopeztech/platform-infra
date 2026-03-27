output "topic_ids" {
  description = "Map of topic short-name → fully qualified topic ID"
  value = {
    for name, topic in google_pubsub_topic.pipeline :
    name => topic.id
  }
}

output "subscription_ids" {
  value = {
    validator  = google_pubsub_subscription.validator.id
    dataflow   = google_pubsub_subscription.dataflow.id
    alerting   = google_pubsub_subscription.alerting.id
    dlq_monitor = google_pubsub_subscription.dlq_monitor.id
  }
}

output "dead_letter_topic_id" {
  value = google_pubsub_topic.dead_letter.id
}
