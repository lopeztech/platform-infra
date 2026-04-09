# Artifact Registry repository for Docker images (used by Cloud Functions v2 builds)
resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = "${local.app_name}-images"
  description   = "Docker images for Plant Tracker"
  format        = "DOCKER"
  project       = var.project_id
  depends_on    = [google_project_service.apis]
}

# Grant deployer SA permission to push images
resource "google_artifact_registry_repository_iam_member" "deployer_writer" {
  location   = google_artifact_registry_repository.app.location
  repository = google_artifact_registry_repository.app.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_deployer.email}"
  project    = var.project_id
}
