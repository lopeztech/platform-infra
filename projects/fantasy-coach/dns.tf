# Cloudflare DNS zone for lopezcloud.dev — shared across every project on
# this domain. The provider reads CLOUDFLARE_API_TOKEN from the environment;
# no credentials are stored in state or config.
provider "cloudflare" {}

data "cloudflare_zone" "lopezcloud" {
  name = "lopezcloud.dev"
}

# Firebase Hosting custom domain — DNS-only (grey cloud) so Firebase provides
# its own CDN and SSL termination. Proxying through Cloudflare would break
# Firebase's managed-certificate issuance (which uses ACME against the CNAME
# target).
resource "cloudflare_record" "fantasy" {
  zone_id = data.cloudflare_zone.lopezcloud.id
  name    = "fantasy"
  type    = "CNAME"
  content = "${google_firebase_hosting_site.app.site_id}.web.app"
  proxied = false
  ttl     = 3600
}
