# Cloudflare provider reads CLOUDFLARE_API_TOKEN from the environment — no
# credentials are stored in state or config.
provider "cloudflare" {}

data "cloudflare_zone" "lopezcloud" {
  name = "lopezcloud.dev"
}

# The plants.lopezcloud.dev A/AAAA records are managed by
# google_firebase_hosting_custom_domain — Cloudflare DNS records for the
# frontend are no longer needed here. Firebase provides its own CDN and SSL,
# so the Cloudflare record must be DNS-only (grey cloud) when set manually.

resource "cloudflare_record" "api" {
  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "api.plants"
  type    = "CNAME"
  value   = google_api_gateway_gateway.app.default_hostname
  proxied = true  # Cloudflare terminates TLS for api.plants.lopezcloud.dev
  ttl     = 1     # Auto — required when proxied
}
