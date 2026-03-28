# Cloudflare provider reads CLOUDFLARE_API_TOKEN from the environment — no
# credentials are stored in state or config.
provider "cloudflare" {}

data "cloudflare_zone" "lopezcloud" {
  name = "lopezcloud.dev"
}

# Firebase Hosting requires two A records pointing to its anycast IPs.
# Proxy must be disabled (DNS-only) so Firebase can complete SSL provisioning
# via its own Let's Encrypt certificate for the custom domain.
locals {
  firebase_hosting_ips = ["151.101.1.195", "151.101.65.195"]
}

resource "cloudflare_record" "datafeeder" {
  count = length(local.firebase_hosting_ips)

  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "datafeeder"
  type    = "A"
  value   = local.firebase_hosting_ips[count.index]
  proxied = false  # DNS-only — Firebase Hosting manages SSL
  ttl     = 3600
}
