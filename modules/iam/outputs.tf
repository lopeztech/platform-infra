output "sa_emails" {
  description = "Map of role name → service account email"
  value = {
    for name, sa in google_service_account.pipeline :
    name => sa.email
  }
}

output "wif_provider_name" {
  description = "Full resource name of the Workload Identity pool provider (used in GitHub Actions)"
  value       = google_iam_workload_identity_pool_provider.github_oidc.name
}
