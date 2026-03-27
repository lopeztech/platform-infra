resource "google_firestore_database" "jobs" {
  project     = var.project_id
  name        = "data-feeder-${var.env}"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  # Enable PITR for prod — 7-day point-in-time recovery
  point_in_time_recovery_enablement = var.env == "prod" ? "POINT_IN_TIME_RECOVERY_ENABLED" : "POINT_IN_TIME_RECOVERY_DISABLED"

  delete_protection_state = var.env == "prod" ? "DELETE_PROTECTION_ENABLED" : "DELETE_PROTECTION_DISABLED"
}

# Composite index: query jobs by dataset, sorted by created_at desc
resource "google_firestore_index" "jobs_by_dataset" {
  project    = var.project_id
  database   = google_firestore_database.jobs.name
  collection = "jobs"

  fields {
    field_path = "dataset"
    order      = "ASCENDING"
  }
  fields {
    field_path = "created_at"
    order      = "DESCENDING"
  }
}

# Composite index: query by status + created_at (powers the job status filter)
resource "google_firestore_index" "jobs_by_status" {
  project    = var.project_id
  database   = google_firestore_database.jobs.name
  collection = "jobs"

  fields {
    field_path = "status"
    order      = "ASCENDING"
  }
  fields {
    field_path = "created_at"
    order      = "DESCENDING"
  }
}
