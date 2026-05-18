# ── Injury intelligence pipeline (fantasy-coach#208) ─────────────────────────
# Two Cloud Run Jobs that populate the `injury_reports` + `late_team_changes`
# Firestore collections. PR D in the app repo (lopeztech/fantasy-coach#269)
# turns these tables into model features; until then the Jobs run but the
# features see zeroes.
#
# Shape matches the precompute Job in scheduler.tf — same runtime SA, same
# image (rotated by the app-repo deploy workflow), same ignore_changes.
#
#   watch-team-lists  — every 15 min on match days (Thu–Mon AEST). The CLI
#                       no-ops when no match is in the kickoff window so a
#                       single cron expression is fine. Emits LateTeamChange
#                       rows when starting-XIII diffs against the most
#                       recent pre-window snapshot.
#   scrape-injuries   — parametrised manual execution for now. The CLI
#                       requires --season + --round; auto-detection is a
#                       separate follow-up. Scheduling will be added once
#                       the CLI can run with no arguments.

# ── Watch-team-lists Job ─────────────────────────────────────────────────────
resource "google_cloud_run_v2_job" "watch_team_lists" {
  name     = "${local.app_name}-watch-team-lists"
  location = var.region
  project  = var.project_id

  template {
    template {
      service_account = google_service_account.runtime.email
      # The CLI fetches the upcoming round's team lists from nrl.com once per
      # match — ~8 sequential HTTP calls at peak. 300s is enough headroom for
      # a slow nrl.com response while still failing fast on stuck runs.
      timeout     = "300s"
      max_retries = 1

      containers {
        # Placeholder. App-repo deploy workflow rotates the image (see
        # cloudrun.tf for the same pattern on the API service).
        image = "us-docker.pkg.dev/cloudrun/container/hello"

        # The cron entry below fires this with no arguments; the CLI then
        # auto-detects season + next upcoming round.
        command = ["python", "-m", "fantasy_coach", "watch-team-lists"]

        env {
          name  = "FIREBASE_PROJECT_ID"
          value = var.project_id
        }
        env {
          name  = "STORAGE_BACKEND"
          value = "firestore"
        }

        resources {
          limits = {
            cpu = "1"
            # gen2 minimum is 512Mi (see cloudrun.tf for the same constraint).
            # The watcher itself is tiny; this is the gen2 floor, not a
            # right-sized number.
            memory = "512Mi"
          }
        }
      }
    }
  }

  labels = local.labels

  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
      template[0].template[0].containers[0].env,
      client,
      client_version,
    ]
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.runtime,
  ]
}

# ── Scrape-injuries Job (manual execution for now) ───────────────────────────
# No Scheduler entry yet — the CLI requires --season + --round, so executions
# are kicked off manually via `gcloud run jobs execute fantasy-coach-scrape-
# injuries --args="--season=2026,--round=12"`. URL is auto-discovered (#268).
# Once the CLI can run with no args, add a weekly Wed AEST cron alongside the
# precompute schedules.
resource "google_cloud_run_v2_job" "scrape_injuries" {
  name     = "${local.app_name}-scrape-injuries"
  location = var.region
  project  = var.project_id

  template {
    template {
      service_account = google_service_account.runtime.email
      # Gemini extraction over a 1-2K-token article: ~5-15s. 600s covers slow
      # Vertex responses and the player-name lookup that fans out across the
      # season's match table.
      timeout     = "600s"
      max_retries = 1

      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"

        # Default args = none. Real invocation passes --season + --round via
        # `gcloud run jobs execute --args=...`. The CLI auto-discovers the
        # NRL.com article URL and reads FIREBASE_PROJECT_ID for the Gemini
        # project, so callers only need to set the round identifiers.
        command = ["python", "-m", "fantasy_coach", "scrape-injuries"]

        env {
          name  = "FIREBASE_PROJECT_ID"
          value = var.project_id
        }
        env {
          name  = "STORAGE_BACKEND"
          value = "firestore"
        }

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
      }
    }
  }

  labels = local.labels

  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
      template[0].template[0].containers[0].env,
      client,
      client_version,
    ]
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.runtime,
    google_project_iam_member.runtime_aiplatform,
  ]
}

# ── Vertex AI grant for scrape-injuries ──────────────────────────────────────
# Gemini parses injury-list prose into structured InjuryReport rows. The
# commentary client uses the same Vertex AI endpoint, so this grant also
# covers the API + precompute Job's match-preview commentary calls (which
# have been working via implicit project-membership perms; making it
# explicit here removes a latent bug).
resource "google_project_iam_member" "runtime_aiplatform" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# ── Scheduler: watch-team-lists every 15 min, Thu-Mon AEST ───────────────────
# Thu (4), Fri (5), Sat (6), Sun (0), Mon (1). The watcher no-ops on days
# with no kickoff window so a single expression is fine; the Mon entry
# catches the occasional Mon-night kickoff. ~96 invocations/match-day —
# trivial cost at 512Mi/1vCPU for a sub-5s no-op.
resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker_watch_team_lists" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.watch_team_lists.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

locals {
  watch_team_lists_run_uri = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.watch_team_lists.name}:run"
}

resource "google_cloud_scheduler_job" "watch_team_lists" {
  name        = "${local.app_name}-watch-team-lists"
  description = "Snapshot starting-XIIIs every 15 min on match days and emit late_team_changes."
  project     = var.project_id
  region      = var.region
  schedule    = "*/15 * * * 1,4,5,6,0"
  time_zone   = "Australia/Sydney"

  http_target {
    uri         = local.watch_team_lists_run_uri
    http_method = "POST"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  retry_config {
    # Single retry — the next 15-min tick will re-pick-up any miss, and
    # double-firing emits duplicate snapshot rows (storage layer dedupes
    # but the extra Gemini call would still incur cost).
    retry_count          = 1
    max_retry_duration   = "0s"
    min_backoff_duration = "30s"
    max_backoff_duration = "120s"
  }

  depends_on = [
    google_project_service.apis,
    google_cloud_run_v2_job_iam_member.scheduler_invoker_watch_team_lists,
  ]
}

# ── Firestore composite indexes for injury_reports ───────────────────────────
# PR D queries:
#   FeatureBuilder reads `where(season).where(round)` for the round's
#   league-wide active injuries, and `where(team_id).where(season).where(round)`
#   for per-team severity/returning counts. Firestore auto-indexes single
#   fields ascending; compound where-clauses need an explicit composite.

resource "google_firestore_index" "injury_reports_by_season_round" {
  project    = var.project_id
  database   = google_firestore_database.default.name
  collection = "injury_reports"

  fields {
    field_path = "season"
    order      = "ASCENDING"
  }
  fields {
    field_path = "round"
    order      = "ASCENDING"
  }
}

resource "google_firestore_index" "injury_reports_by_team_season_round" {
  project    = var.project_id
  database   = google_firestore_database.default.name
  collection = "injury_reports"

  fields {
    field_path = "team_id"
    order      = "ASCENDING"
  }
  fields {
    field_path = "season"
    order      = "ASCENDING"
  }
  fields {
    field_path = "round"
    order      = "ASCENDING"
  }
}
