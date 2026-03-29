output "notification_channel_id" {
  description = "Notification channel resource name"
  value       = google_monitoring_notification_channel.email.name
}

output "uptime_check_ids" {
  description = "Map of service name to uptime check ID"
  value = {
    for name, check in google_monitoring_uptime_check_config.https :
    name => check.uptime_check_id
  }
}
