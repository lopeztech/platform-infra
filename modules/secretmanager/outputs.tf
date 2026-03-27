output "secret_ids" {
  value = {
    for name, secret in google_secret_manager_secret.pipeline :
    name => secret.id
  }
}
