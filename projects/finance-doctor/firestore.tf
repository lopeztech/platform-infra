import {
  to = google_firestore_database.default
  id = "projects/finance-doctor-lcd/databases/(default)"
}

resource "google_firestore_database" "default" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.apis]
}
