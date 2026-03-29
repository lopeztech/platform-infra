# ── Static IP ─────────────────────────────────────────────────────────────────

resource "google_compute_global_address" "app" {
  name       = "${local.app_name}-ip-${var.environment}"
  ip_version = "IPV4"

  depends_on = [google_project_service.apis]
}

# ── Google-Managed SSL Certificate ────────────────────────────────────────────

resource "google_compute_managed_ssl_certificate" "app" {
  name = "${local.app_name}-cert-${var.environment}"

  managed {
    domains = [var.domain]
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_project_service.apis]
}

# ── Backend Service — Cloud Run API ────────────────────────────────────────────
# Serves /api/* requests via Cloud Run.

resource "google_compute_backend_service" "app" {
  name                  = "${local.app_name}-backend-${var.environment}"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL"
  enable_cdn            = true

  backend {
    group = google_compute_region_network_endpoint_group.app.id
  }

  cdn_policy {
    cache_mode                   = "USE_ORIGIN_HEADERS"
    default_ttl                  = var.cdn_default_ttl
    max_ttl                      = var.cdn_max_ttl
    client_ttl                   = var.cdn_default_ttl
    negative_caching             = true
    serve_while_stale            = 86400
    signed_url_cache_max_age_sec = 0
  }

  log_config {
    enable = true
  }
}

# ── Backend Bucket — GCS static React app ─────────────────────────────────────
# Serves the compiled React SPA from GCS via CDN.

resource "google_compute_backend_bucket" "app_static" {
  name        = "${local.app_name}-static-${var.environment}"
  bucket_name = google_storage_bucket.app.name
  enable_cdn  = true

  cdn_policy {
    cache_mode                   = "USE_ORIGIN_HEADERS"
    default_ttl                  = var.cdn_default_ttl
    max_ttl                      = var.cdn_max_ttl
    client_ttl                   = var.cdn_default_ttl
    negative_caching             = true
    serve_while_stale            = 86400
  }
}

# ── URL Map ────────────────────────────────────────────────────────────────────
# Default → GCS backend bucket (React SPA), /api/* → Cloud Run.

resource "google_compute_url_map" "app_https" {
  name            = "${local.app_name}-url-map-${var.environment}"
  default_service = google_compute_backend_bucket.app_static.id

  host_rule {
    hosts        = [var.domain]
    path_matcher = "app"
  }

  path_matcher {
    name            = "app"
    default_service = google_compute_backend_bucket.app_static.id

    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_service.app.id
    }
  }
}

# ── HTTPS Proxy ────────────────────────────────────────────────────────────────

resource "google_compute_target_https_proxy" "app" {
  name             = "${local.app_name}-https-proxy-${var.environment}"
  url_map          = google_compute_url_map.app_https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.app.id]
}

# ── Forwarding Rules ───────────────────────────────────────────────────────────

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${local.app_name}-https-forwarding-${var.environment}"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.app.id
  ip_address            = google_compute_global_address.app.address
}

resource "google_compute_url_map" "http_redirect" {
  name = "${local.app_name}-http-redirect-${var.environment}"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "${local.app_name}-http-proxy-${var.environment}"
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${local.app_name}-http-forwarding-${var.environment}"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.redirect.id
  ip_address            = google_compute_global_address.app.address
}
