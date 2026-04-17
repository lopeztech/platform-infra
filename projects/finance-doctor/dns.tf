# Cloudflare provider reads CLOUDFLARE_API_TOKEN from the environment — no
# credentials are stored in state or config.
provider "cloudflare" {}

data "cloudflare_zone" "lopezcloud" {
  name = "lopezcloud.dev"
}

# Firebase Hosting custom domain — DNS-only (grey cloud) so Firebase
# provides its own CDN and SSL. Production traffic does not move to this
# record until #54 cuts over; until then Cloud Run continues to serve the
# app at its *.run.app URL.
resource "cloudflare_record" "finance" {
  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "finance"
  type    = "CNAME"
  content = "${google_firebase_hosting_site.app.site_id}.web.app"
  proxied = false
  ttl     = 3600
}
