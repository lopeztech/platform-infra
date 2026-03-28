output "service_url" {
  description = "Publicly reachable Cloud Run service URL"
  value       = google_cloud_run_v2_service.api.uri
}

output "service_name" {
  description = "Cloud Run service name (used by domain mapping)"
  value       = google_cloud_run_v2_service.api.name
}
