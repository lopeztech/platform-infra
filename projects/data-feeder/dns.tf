# Cloudflare provider reads CLOUDFLARE_API_TOKEN from the environment — no
# credentials are stored in state or config.
provider "cloudflare" {}

data "cloudflare_zone" "lopezcloud" {
  name = "lopezcloud.dev"
}

# Firebase Hosting custom domain — DNS-only (grey cloud) so Firebase
# provides its own CDN and SSL.
resource "cloudflare_record" "datafeeder" {
  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "datafeeder"
  type    = "CNAME"
  content = "${google_firebase_hosting_site.data_feeder.site_id}.web.app"
  proxied = false # DNS-only — Firebase handles CDN and TLS
  ttl     = 3600
}
