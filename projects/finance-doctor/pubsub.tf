# ── Pub/Sub — Bulk Expense Categorisation Fan-out ────────────────────────────
# Backs the `expensesCategoriseWorker` Firebase Function. On bulk CSV imports
# (>50 rows), `expensesImport` saves rows with categorisationStatus=pending and
# publishes one message per row to this topic; the worker then calls Gemini
# per-row and patches Firestore. Small imports keep the synchronous AI-at-
# preview flow and do not touch this topic.

resource "google_pubsub_topic" "expense_categorise" {
  name    = "expense-categorise"
  project = var.project_id

  message_retention_duration = "604800s" # 7 days

  labels = local.labels

  depends_on = [google_project_service.apis]
}

# Functions runtime SA publishes per-expense messages during bulk imports.
resource "google_pubsub_topic_iam_member" "functions_runtime_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.expense_categorise.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.functions_runtime.email}"
}

# Firebase Functions v2 Pub/Sub triggers deliver via Eventarc. The runtime SA
# needs eventarc.eventReceiver at the project level for Eventarc to invoke the
# worker's underlying Cloud Run service.
resource "google_project_iam_member" "functions_runtime_eventarc_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.functions_runtime.email}"
}
