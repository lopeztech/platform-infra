# Cloudflare provider reads CLOUDFLARE_API_TOKEN from the environment — no
# credentials are stored in state or config.
provider "cloudflare" {}

data "cloudflare_zone" "lopezcloud" {
  name = "lopezcloud.dev"
}

# CNAME to ghs.googlehosted.com for Cloud Run domain mapping.
# Cloudflare proxy is disabled so Google can verify domain ownership
# and provision the managed SSL certificate.
resource "cloudflare_record" "app" {
  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "finance"
  type    = "CNAME"
  value   = "ghs.googlehosted.com"
  proxied = false
  ttl     = 3600
}
