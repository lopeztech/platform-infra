#!/usr/bin/env bash
# Discovers WIF provider names and service account emails from GCP and sets
# all required GitHub Actions secrets for lopeztech/platform-infra.
#
# Prerequisites: gcloud (authenticated), gh (authenticated)
set -euo pipefail

REPO="lopeztech/platform-infra"

echo "==> Discovering GCP values..."

# ── home-plant-tracker ─────────────────────────────────────────────────────────
HPT_PROJECT="home-plant-tracker-lcd"
HPT_WIF_PROVIDER=$(gcloud iam workload-identity-pools providers describe github-provider \
  --workload-identity-pool="plant-tracker-github-pool" \
  --project="$HPT_PROJECT" \
  --location=global \
  --format="value(name)")
HPT_SA_EMAIL=$(gcloud iam service-accounts describe \
  "plant-tracker-deployer@${HPT_PROJECT}.iam.gserviceaccount.com" \
  --project="$HPT_PROJECT" \
  --format="value(email)")

# ── sre-monitor ────────────────────────────────────────────────────────────────
SRE_PROJECT="sre-monitor-lcd"
SRE_WIF_PROVIDER=$(gcloud iam workload-identity-pools providers describe github-provider \
  --workload-identity-pool="sre-monitor-github-pool" \
  --project="$SRE_PROJECT" \
  --location=global \
  --format="value(name)")
SRE_SA_EMAIL=$(gcloud iam service-accounts describe \
  "sre-monitor-deployer@${SRE_PROJECT}.iam.gserviceaccount.com" \
  --project="$SRE_PROJECT" \
  --format="value(email)")

# ── data-feeder ────────────────────────────────────────────────────────────────
# The workflow uses a single DATA_FEEDER_WIF_PROVIDER secret across dev/staging/prod.
# The iam module creates one pool per env; we use prod as the canonical provider.
DF_PROJECT="data-feeder-lcd"
DF_WIF_PROVIDER=$(gcloud iam workload-identity-pools providers describe github-oidc-prod \
  --workload-identity-pool="github-pool-prod" \
  --project="$DF_PROJECT" \
  --location=global \
  --format="value(name)")
DF_SA_EMAIL=$(gcloud iam service-accounts describe \
  "sa-cicd-prod@${DF_PROJECT}.iam.gserviceaccount.com" \
  --project="$DF_PROJECT" \
  --format="value(email)")

# ── TF state bucket (from bootstrap/terraform.tfvars: project_id=platform-infra-lcd) ──
TF_STATE_BUCKET="platform-infra-lcd-tf-state"

# ── Print discovered values ────────────────────────────────────────────────────
echo ""
echo "Discovered values:"
echo "  TF_STATE_BUCKET=$TF_STATE_BUCKET"
echo "  HOME_PLANT_TRACKER_WIF_PROVIDER=$HPT_WIF_PROVIDER"
echo "  HOME_PLANT_TRACKER_SA_EMAIL=$HPT_SA_EMAIL"
echo "  SRE_MONITOR_WIF_PROVIDER=$SRE_WIF_PROVIDER"
echo "  SRE_MONITOR_SA_EMAIL=$SRE_SA_EMAIL"
echo "  DATA_FEEDER_WIF_PROVIDER=$DF_WIF_PROVIDER"
echo "  DATA_FEEDER_SA_EMAIL=$DF_SA_EMAIL"
echo ""

# ── Set GitHub secrets ─────────────────────────────────────────────────────────
echo "==> Setting GitHub secrets on ${REPO}..."

gh secret set TF_STATE_BUCKET                 --repo "$REPO" --body "$TF_STATE_BUCKET"
gh secret set HOME_PLANT_TRACKER_WIF_PROVIDER --repo "$REPO" --body "$HPT_WIF_PROVIDER"
gh secret set HOME_PLANT_TRACKER_SA_EMAIL     --repo "$REPO" --body "$HPT_SA_EMAIL"
gh secret set SRE_MONITOR_WIF_PROVIDER        --repo "$REPO" --body "$SRE_WIF_PROVIDER"
gh secret set SRE_MONITOR_SA_EMAIL            --repo "$REPO" --body "$SRE_SA_EMAIL"
gh secret set DATA_FEEDER_WIF_PROVIDER        --repo "$REPO" --body "$DF_WIF_PROVIDER"
gh secret set DATA_FEEDER_SA_EMAIL            --repo "$REPO" --body "$DF_SA_EMAIL"

echo ""
echo "Done! All discoverable secrets set."
echo ""
echo "Set these remaining secrets manually (values not in GCP):"
echo "  gh secret set GEMINI_API_KEY --repo $REPO"
echo "  gh secret set HOME_PLANT_TRACKER_FUNCTION_SOURCE_OBJECT --repo $REPO"
