# ── Static IP ─────────────────────────────────────────────────────────────────

resource "google_compute_global_address" "app" {
  name       = "data-feeder-ip"
  ip_version = "IPV4"

  depends_on = [google_project_service.apis]
}

# ── Serverless NEG — connects the Load Balancer to Cloud Run ─────────────────

resource "google_compute_region_network_endpoint_group" "app" {
  name                  = "data-feeder-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  project               = var.project_id

  cloud_run {
    service = module.cloudrun.service_name
  }

  depends_on = [google_project_service.apis]
}

# ── Backend Service ───────────────────────────────────────────────────────────

resource "google_compute_backend_service" "app" {
  name                  = "data-feeder-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL"

  backend {
    group = google_compute_region_network_endpoint_group.app.id
  }

  log_config {
    enable = true
  }
}

# ── Google-Managed SSL Certificate ────────────────────────────────────────────

resource "google_compute_managed_ssl_certificate" "app" {
  name = "data-feeder-cert"

  managed {
    domains = [var.domain]
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_project_service.apis]
}

# ── URL Map ───────────────────────────────────────────────────────────────────

resource "google_compute_url_map" "app_https" {
  name            = "data-feeder-url-map"
  default_service = google_compute_backend_service.app.id
}

# ── HTTPS Proxy ───────────────────────────────────────────────────────────────

resource "google_compute_target_https_proxy" "app" {
  name             = "data-feeder-https-proxy"
  url_map          = google_compute_url_map.app_https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.app.id]
}

# ── Forwarding Rules ─────────────────────────────────────────────────────────

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "data-feeder-https-forwarding"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.app.id
  ip_address            = google_compute_global_address.app.address
}

# ── HTTP → HTTPS Redirect ────────────────────────────────────────────────────

resource "google_compute_url_map" "http_redirect" {
  name = "data-feeder-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "data-feeder-http-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "data-feeder-http-forwarding"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.redirect.id
  ip_address            = google_compute_global_address.app.address
}
