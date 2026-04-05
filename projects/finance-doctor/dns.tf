# Cloudflare provider reads CLOUDFLARE_API_TOKEN from the environment — no
# credentials are stored in state or config.
provider "cloudflare" {}

data "cloudflare_zone" "lopezcloud" {
  name = "lopezcloud.dev"
}

# CNAME to the Cloud Run service URL.
# Cloudflare proxy (orange cloud) handles SSL termination and caching.
resource "cloudflare_record" "app" {
  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "finance"
  type    = "CNAME"
  value   = trimprefix(google_cloud_run_v2_service.app.uri, "https://")
  proxied = true  # Cloudflare handles SSL + CDN for free
  ttl     = 1     # auto when proxied
}
