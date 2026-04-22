# ── Firestore ────────────────────────────────────────────────────────────────
# Shared state between the Cloud Run API and the precompute Job (fantasy-
# coach#65). The app-repo side (#15) shipped the ``FirestoreRepository`` +
# ``FirestorePredictionStore`` code; the provisioning that should have
# accompanied it is caught up here.
#
# Uses the project's (default) database because ``FirestoreRepository`` and
# ``FirestorePredictionStore`` both default to ``database="(default)"``.
# Regional (australia-southeast1) keeps reads near the Cloud Run service,
# which is in the same region. Delete protection + PITR are on because
# losing the match history here means re-running a multi-hour backfill.

resource "google_firestore_database" "default" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_ENABLED"
  delete_protection_state           = "DELETE_PROTECTION_ENABLED"

  depends_on = [google_project_service.apis]
}

# Composite index: ``list_matches(season)`` queries filter on season and
# order by ``start_time`` then ``match_id``. Firestore auto-creates
# single-field indexes but requires a composite for the filter+order
# combination. Without this, the query fails at runtime with
# "this query requires an index".

resource "google_firestore_index" "matches_by_season" {
  project    = var.project_id
  database   = google_firestore_database.default.name
  collection = "matches"

  fields {
    field_path = "season"
    order      = "ASCENDING"
  }
  fields {
    field_path = "start_time"
    order      = "ASCENDING"
  }
  fields {
    field_path = "match_id"
    order      = "ASCENDING"
  }
}

# Composite index: ``list_matches(season, round)`` — same sort, extra filter.
# Needed because Firestore can't combine an arbitrary where-filter with an
# order-by unless a matching composite index exists.

resource "google_firestore_index" "matches_by_season_round" {
  project    = var.project_id
  database   = google_firestore_database.default.name
  collection = "matches"

  fields {
    field_path = "season"
    order      = "ASCENDING"
  }
  fields {
    field_path = "round"
    order      = "ASCENDING"
  }
  fields {
    field_path = "start_time"
    order      = "ASCENDING"
  }
  fields {
    field_path = "match_id"
    order      = "ASCENDING"
  }
}

# No composite index needed for the ``predictions`` collection —
# ``FirestorePredictionStore`` reads by document ID (``"{season}-{round}"``),
# which Firestore resolves without any index at all.
