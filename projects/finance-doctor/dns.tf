# Cloudflare provider reads CLOUDFLARE_API_TOKEN from the environment — no
# credentials are stored in state or config.
provider "cloudflare" {}

# Custom domain DNS is not used — Cloud Run domain mapping is unsupported in
# australia-southeast1. The app is served directly via the Cloud Run URL:
#   https://finance-doctor-ws5d6symma-ts.a.run.app
#
# To add a custom domain later, either:
#   1. Move Cloud Run to a region that supports domain mapping (e.g. us-central1)
#   2. Add a GCP load balancer with a managed SSL certificate
