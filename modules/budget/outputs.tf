output "budget_name" {
  description = "The resource name of the budget"
  value       = google_billing_budget.project.name
}

output "notification_channel_id" {
  description = "The notification channel resource name"
  value       = google_monitoring_notification_channel.budget_email.name
}
