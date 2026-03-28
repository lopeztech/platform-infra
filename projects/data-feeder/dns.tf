# Cloudflare provider reads CLOUDFLARE_API_TOKEN from the environment — no
# credentials are stored in state or config.
provider "cloudflare" {}

data "cloudflare_zone" "lopezcloud" {
  name = "lopezcloud.dev"
}

# Cloud Run domain mapping provisions a Google-managed SSL certificate and
# requires a CNAME pointing to ghs.googlehosted.com.  Proxy must be disabled
# (DNS-only) so Google can complete certificate validation.
resource "cloudflare_record" "datafeeder" {
  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "datafeeder"
  type    = "CNAME"
  value   = "ghs.googlehosted.com"
  proxied = false  # DNS-only — Google manages SSL
  ttl     = 3600
}
