# Cloudflare provider reads CLOUDFLARE_API_TOKEN from the environment — no
# credentials are stored in state or config.
provider "cloudflare" {}

data "cloudflare_zone" "lopezcloud" {
  name = "lopezcloud.dev"
}

resource "cloudflare_record" "datafeeder" {
  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "datafeeder"
  type    = "A"
  value   = google_compute_global_address.app.address
  proxied = false  # DNS-only — Google-managed SSL handles TLS
  ttl     = 3600
}
