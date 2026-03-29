# Cloudflare provider reads CLOUDFLARE_API_TOKEN from the environment — no
# credentials are stored in state or config.
provider "cloudflare" {}

data "cloudflare_zone" "lopezcloud" {
  name = "lopezcloud.dev"
}

resource "cloudflare_record" "app" {
  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "plants"
  type    = "A"
  value   = google_compute_global_address.app.address
  proxied = false  # DNS-only — Google-managed SSL handles TLS
  ttl     = 3600
}

resource "cloudflare_record" "api" {
  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "api.plants"
  type    = "CNAME"
  value   = google_api_gateway_gateway.app.default_hostname
  proxied = true  # Cloudflare terminates TLS for api.plants.lopezcloud.dev
}
