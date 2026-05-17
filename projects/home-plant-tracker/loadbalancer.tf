# ── Global External HTTPS Load Balancer for api.${var.domain} ────────────────
#
# Fronts the API Gateway with a Google-managed cert so that Stripe (and any
# other strict TLS client) can complete the handshake against
# api.plants.lopezcloud.dev. Previously the hostname was Cloudflare-proxied
# CNAME → *.gateway.dev, but Cloudflare's edge had no valid cert for that
# subdomain so the handshake failed at TLS alert 40. Replacing the proxy with
# a serverless-NEG → API Gateway LB gives single-vendor managed TLS and drops
# Cloudflare from the API path (DNS-only A record below).

resource "google_compute_global_address" "api" {
  name    = "${local.app_name}-api-ip"
  project = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_compute_region_network_endpoint_group" "api_gateway" {
  provider              = google-beta
  name                  = "${local.app_name}-api-gateway-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  serverless_deployment {
    platform = "apigateway.googleapis.com"
    resource = google_api_gateway_gateway.app.gateway_id
  }

  depends_on = [google_project_service.apis]
}

resource "google_compute_backend_service" "api" {
  name                  = "${local.app_name}-api-backend"
  project               = var.project_id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"

  backend {
    group = google_compute_region_network_endpoint_group.api_gateway.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [google_project_service.apis]
}

resource "google_compute_url_map" "api" {
  name            = "${local.app_name}-api-urlmap"
  project         = var.project_id
  default_service = google_compute_backend_service.api.id
}

resource "google_compute_managed_ssl_certificate" "api" {
  name    = "${local.app_name}-api-cert"
  project = var.project_id

  managed {
    domains = ["api.${var.domain}"]
  }

  # Replacing a managed cert in place fails — Google requires create-before-destroy
  # so the new cert can be attached to the proxy before the old one is removed.
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_project_service.apis]
}

resource "google_compute_target_https_proxy" "api" {
  name             = "${local.app_name}-api-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.api.id
  ssl_certificates = [google_compute_managed_ssl_certificate.api.id]
}

resource "google_compute_global_forwarding_rule" "api" {
  name                  = "${local.app_name}-api-fr"
  project               = var.project_id
  target                = google_compute_target_https_proxy.api.id
  port_range            = "443"
  ip_address            = google_compute_global_address.api.address
  load_balancing_scheme = "EXTERNAL_MANAGED"

  labels = local.labels
}
