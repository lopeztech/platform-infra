# Cloudflare provider reads CLOUDFLARE_API_TOKEN from the environment — no
# credentials are stored in state or config.
provider "cloudflare" {}

data "cloudflare_zone" "lopezcloud" {
  name = "lopezcloud.dev"
}

# Firebase Hosting custom domain — DNS-only (grey cloud) so Firebase
# provides its own CDN and SSL.
resource "cloudflare_record" "app" {
  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "plants"
  type    = "CNAME"
  content = "${google_firebase_hosting_site.plant_tracker.site_id}.web.app"
  proxied = false  # DNS-only — Firebase handles CDN and TLS
  ttl     = 3600
}

resource "cloudflare_record" "api" {
  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "api.plants"
  type    = "CNAME"
  content = google_api_gateway_gateway.app.default_hostname
  proxied = true  # Cloudflare terminates TLS for api.plants.lopezcloud.dev
  ttl     = 1     # Auto — required when proxied
}
